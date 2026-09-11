defmodule MiniLineage.Characters.Server do
  @moduledoc """
  One process per character. A GenServer handles one message at a time, which is what replaces the
  reference's hand-rolled per-session promise mutex — concurrent actions cannot interleave here by
  construction.

  It also owns the two timers the reference ran centrally: the 5s regeneration cadence, and a
  single expiry timer re-armed at the earliest upcoming effect deadline.
  """
  use GenServer, restart: :transient

  alias MiniLineage.BattleLog
  alias MiniLineage.Characters.Store
  require Logger

  alias MiniLineage.Game.{Clock, Constants, Format, Player}

  # Fires just past the deadline so the sweep reliably sees the effect as due.
  @expiry_grace_ms 25
  # How long the process outlives its last viewer before stopping. Its buffer is flushed on the way.
  @idle_grace_ms Application.compile_env(:mini_lineage, :character_idle_grace_ms, 10_000)

  # Changes confined to these are the passage of time and where the player is standing. Everything
  # else is something they did, and is written before they are told it worked.
  #
  # Derived from the struct rather than declared per call site, for the same reason `changed?` is:
  # a call site that forgets to ask for a flush loses data silently, and a diff cannot forget.
  @buffered ~w(health current_screen effects combat_until)a

  # A player who is connected but idle — watching health refill — triggers neither an action nor a
  # stop, so nothing would write. This bounds how long that buffer can sit unwritten.
  @backstop_ms 60_000

  def start_link(id), do: GenServer.start_link(__MODULE__, id, name: via(id))

  def via(id), do: {:via, Registry, {MiniLineage.Characters.Registry, id}}

  @impl true
  def init(id) do
    # Without this the process dies on its parent's exit signal and `terminate/2` never runs, so an
    # ordinary shutdown would discard whatever is buffered.
    Process.flag(:trap_exit, true)

    # The narrative is no longer in the document, so the screen is refilled from the log — one
    # query, and only when the process starts.
    player = Store.load(id) || %Player{}
    player = %{player | last_battle_narrative: BattleLog.last_for(id)}
    schedule_tick()

    state = %{
      id: id,
      player: player,
      expiry_timer: nil,
      viewers: %{},
      stop_timer: nil,
      dirty_since: nil,
      pending_battles: []
    }

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
    state = backstop(state)

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

  @impl true
  def terminate(_reason, state), do: flush_pending(state)

  # ------------------------------------------------------------------- core

  defp backstop(%{dirty_since: nil} = state), do: state

  defp backstop(state) do
    if Clock.now_ms() - state.dirty_since >= @backstop_ms, do: persist(state), else: state
  end

  defp flush_pending(%{dirty_since: nil} = state), do: state
  defp flush_pending(state), do: persist(state)

  # sync/sweep -> mutate -> sync -> persist -> broadcast, serialised by the process itself. Whether
  # anything changed is decided by comparing the struct, never by a handler remembering to say so.
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

    if changed? do
      # Always broadcast: a viewer must see the tick whether or not it was worth a write.
      broadcast(state.id, player)

      state =
        %{state | player: player}
        |> log_battle(before, player)
        |> close_life(before, player, result)

      {result, arm_expiry(if(flush?(before, player), do: persist(state), else: mark(state)))}
    else
      {result, state}
    end
  end

  # Anything outside @buffered is the player's own doing, and is written before they see the result.
  defp flush?(before, now) do
    before
    |> Map.from_struct()
    |> Enum.any?(fn {field, was} -> field not in @buffered and Map.get(now, field) != was end)
  end

  # A fight is the only thing that sets a new narrative, so this is how the process notices one
  # without Actions having to reach for the database itself.
  defp log_battle(state, before, now) do
    if now.last_battle_narrative && now.last_battle_narrative != before.last_battle_narrative do
      %{
        state
        | pending_battles:
            state.pending_battles ++ [BattleLog.row(state.id, now.last_battle_narrative)]
      }
    else
      state
    end
  end

  # A life ends when the character is reset — by writing a legacy, or by starting over without one.
  # Claimed fights outlive the character; the rest go, so the next life does not inherit them.
  defp close_life(state, before, now, result) do
    if Player.started?(before) and not Player.started?(now) do
      case result do
        {:ok, %{highscore_id: id}} when is_integer(id) -> BattleLog.claim(state.id, id)
        _ -> BattleLog.discard_unclaimed(state.id)
      end
    end

    state
  end

  defp mark(%{dirty_since: nil} = state), do: %{state | dirty_since: Clock.now_ms()}
  defp mark(state), do: state

  # Never raises. Once there is a buffer, letting a database error kill the process would take the
  # buffer with it — so a failure keeps the state dirty and the next flush carries it.
  defp persist(state) do
    Store.save(state.id, state.player, state.pending_battles)

    %{state | dirty_since: nil, pending_battles: []}
  rescue
    error ->
      Logger.error("💾 character #{state.id} failed to persist, still buffered: #{inspect(error)}")

      mark(state)
  end

  defp sweep(player) do
    {player, _changed} = Player.process_effect_expiry(player)
    player
  end

  defp expiring(player) do
    now = Clock.now_ms()

    Enum.filter(player.effects, &(&1.expires_at != nil and &1.expires_at <= now))
  end

  # `[TICK:<id>] <Zone> | HP: <old> -> <new>/<max> (<status>)`. The zone reads the RESTING aura, not
  # the absence of combat: a screen in neither list is its own case, not a mislabelled "Resting".
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
  defp same?(a, b), do: a == b

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
