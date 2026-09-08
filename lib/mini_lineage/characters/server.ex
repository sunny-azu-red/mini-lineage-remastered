defmodule MiniLineage.Characters.Server do
  @moduledoc """
  One process per character. A GenServer handles one message at a time, which is what replaces the
  reference's hand-rolled per-session promise mutex — concurrent actions cannot interleave here by
  construction.

  It also owns the two timers the reference ran centrally: the 5s regeneration cadence, and a
  single expiry timer re-armed at the earliest upcoming effect deadline.
  """
  use GenServer, restart: :transient

  alias MiniLineage.Characters.Store
  require Logger

  alias MiniLineage.Game.{Clock, Constants, Format, Player}

  # Fires just past the deadline so the sweep reliably sees the effect as due.
  @expiry_grace_ms 25
  # How long the process outlives its last viewer before stopping. State is already persisted.
  @idle_grace_ms Application.compile_env(:mini_lineage, :character_idle_grace_ms, 10_000)

  def start_link(id), do: GenServer.start_link(__MODULE__, id, name: via(id))

  def via(id), do: {:via, Registry, {MiniLineage.Characters.Registry, id}}

  @impl true
  def init(id) do
    player = Store.load(id) || %Player{}
    schedule_tick()

    state = %{id: id, player: player, expiry_timer: nil, viewers: %{}, stop_timer: nil}

    # Armed from the start rather than only when a viewer leaves: a process opened by a plain read
    # — a dead render, a crawler — never attaches one, and would otherwise never stop.
    {:ok, state |> arm_expiry() |> schedule_stop()}
  end

  # -------------------------------------------------------------------- calls

  @impl true
  def handle_call({:mutate, fun}, _from, state) do
    {result, state} = run(state, fun)

    {:reply, result, state}
  end

  def handle_call(:snapshot, _from, state) do
    # A read still goes through the load-time sweep, so a stale buff is never shown as live.
    {_result, state} = run(state, &{&1, :ok})

    {:reply, state.player, state}
  end

  def handle_call({:attach, pid}, _from, state) do
    ref = Process.monitor(pid)
    state = cancel_stop(%{state | viewers: Map.put(state.viewers, ref, pid)})

    {:reply, :ok, state}
  end

  # ------------------------------------------------------------------- infos

  @impl true
  def handle_info(:tick, state) do
    schedule_tick()

    # A visitor who has not created a character has nothing to regenerate, and no health for the
    # tick log to describe. The timer keeps running: the character may yet be created in here.
    if Player.started?(state.player) do
      {_result, state} = run(state, &Player.process_regen_tick/1, log: true)

      {:noreply, state}
    else
      {:noreply, state}
    end
  end

  def handle_info(:expiry, state) do
    # The sweep itself lives in run/2; this firing exists purely to make it happen on time.
    {_result, state} = run(%{state | expiry_timer: nil}, &{&1, :ok}, log: true)

    {:noreply, state}
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    viewers = Map.delete(state.viewers, ref)
    state = %{state | viewers: viewers}

    {:noreply, if(map_size(viewers) == 0, do: schedule_stop(state), else: state)}
  end

  def handle_info(:stop_if_idle, %{viewers: viewers} = state) when map_size(viewers) == 0,
    do: {:stop, :normal, state}

  def handle_info(:stop_if_idle, state), do: {:noreply, %{state | stop_timer: nil}}

  # ------------------------------------------------------------------- core

  # lock -> load-time sync/sweep -> mutate -> post-sync -> persist -> broadcast. The lock is the
  # process itself. Whether anything changed is decided by comparing the struct, so a handler
  # never has to remember to report it. `fun` returns `{player, result}`, the same shape every
  # game function already returns, so they compose here without a wrapper.
  defp run(state, fun, opts \\ []) do
    before = state.player

    player = sync(before)
    # Captured before the sweep's clamp, so a lapsed max-health buff still shows its HP drop.
    health_before = player.health
    expired = expiring(player)
    player = sweep(player)

    {player, result} = fun.(player)
    player = sync(player)

    changed? = not same?(before, player)
    if opts[:log], do: log_tick(state.id, player, health_before, expired, changed?)

    if same?(before, player) do
      {result, state}
    else
      player = %{player | revision: player.revision + 1}
      Store.save(state.id, player)
      broadcast(state.id, player)

      {result, arm_expiry(%{state | player: player})}
    end
  end

  defp sweep(player) do
    {player, _changed} = Player.process_effect_expiry(player)
    player
  end

  defp expiring(player) do
    now = Clock.now_ms()

    Enum.filter(player.effects, &(&1.expires_at != nil and &1.expires_at <= now))
  end

  # One line per firing: `[TICK:<id>] <Zone> | HP: <old> -> <new>/<max> (<status>)`.
  #
  # The zone reads the RESTING aura rather than the absence of combat: regeneration is granted by
  # that aura, so a screen in neither zone list is its own case rather than a mislabelled "Resting"
  # logged beside a tick that did nothing.
  defp log_tick(id, player, health_before, expired, changed?) do
    stats = Player.stats(player)
    dead? = player.dead or player.health <= 0
    combat? = not dead? and Enum.any?(player.effects, &(&1.id == "combat"))
    resting? = not dead? and Enum.any?(player.effects, &(&1.id == "resting"))

    zone =
      cond do
        dead? -> "Dead"
        combat? -> "In Combat"
        resting? -> "Resting"
        true -> "No Zone"
      end

    difference = player.health - health_before
    moved = if difference != 0, do: "#{health_before} -> ", else: ""

    labels = Enum.map_join(expired, ", ", & &1.label)

    kind =
      if expired == [],
        do: "Effect",
        else: expired |> hd() |> Map.fetch!(:type) |> to_string() |> Format.capitalize()

    suffix = if labels == "", do: "", else: ": #{labels}"

    status =
      cond do
        difference > 0 -> "+#{difference} HPR"
        difference < 0 -> "#{difference} HP | #{kind} Expired#{suffix}"
        changed? and labels != "" -> "#{kind} Expired#{suffix}"
        changed? -> "Effect Expired"
        player.health >= stats.max_health -> "Full"
        combat? or dead? or not resting? -> "Paused"
        stats.regen == 0 -> "0 HPR"
        true -> "Idle"
      end

    Logger.debug(
      "[TICK:#{String.slice(id, 0, 7)}] #{zone} | HP: #{moved}#{player.health}/#{stats.max_health} (#{status})"
    )
  end

  defp sync(player) do
    if Player.started?(player) do
      {player, _changed} = Player.sync_zone_auras(player)
      player
    else
      player
    end
  end

  # Revision is excluded: it is the record OF a change, never a reason to persist one.
  defp same?(a, b), do: %{a | revision: 0} == %{b | revision: 0}

  defp schedule_tick, do: Process.send_after(self(), :tick, Constants.tick_interval_ms())

  defp schedule_stop(state),
    do: %{state | stop_timer: Process.send_after(self(), :stop_if_idle, @idle_grace_ms)}

  defp cancel_stop(%{stop_timer: nil} = state), do: state

  defp cancel_stop(state) do
    Process.cancel_timer(state.stop_timer)

    %{state | stop_timer: nil}
  end

  # Always cleared and re-armed whole, so there is never a question of which timer still applies.
  defp arm_expiry(state) do
    if state.expiry_timer, do: Process.cancel_timer(state.expiry_timer)

    deadlines = for e <- state.player.effects, e.expires_at, do: e.expires_at

    timer =
      case deadlines do
        [] ->
          nil

        _ ->
          delay = max(0, Enum.min(deadlines) - Clock.now_ms() + @expiry_grace_ms)
          Process.send_after(self(), :expiry, delay)
      end

    %{state | expiry_timer: timer}
  end

  defp broadcast(id, player),
    do:
      Phoenix.PubSub.broadcast(
        MiniLineage.PubSub,
        "character:#{id}",
        {:character_updated, player}
      )
end
