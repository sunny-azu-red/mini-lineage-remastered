defmodule MiniLineage.Characters.Server do
  @moduledoc """
  One process per character. The mailbox serialises, so concurrent actions cannot interleave. It
  owns both timers too: the 5s regeneration cadence, and one expiry timer re-armed at the earliest
  upcoming effect deadline.
  """
  use GenServer, restart: :transient

  alias MiniLineage.{BattleLog, Board}
  alias MiniLineage.Characters.{Store, TickLog}
  require Logger

  alias MiniLineage.Game.{Clock, Constants, Player}

  # Fires just past the deadline so the sweep reliably sees the effect as due.
  @expiry_grace_ms 25
  # How long the process outlives its last viewer before stopping. Its buffer is flushed on the way.
  @idle_grace_ms Application.compile_env(:mini_lineage, :character_idle_grace_ms, 10_000)

  # The passage of time and where the player is standing; everything else is something they did.
  # Derived from the struct, not declared per call site, because a call site can forget to flush.
  @buffered ~w(health current_screen effects combat_until)a

  # A connected but idle player triggers neither an action nor a stop, so nothing would write.
  @backstop_ms 60_000

  def start_link(session), do: GenServer.start_link(__MODULE__, session, name: via(session))

  def via(session), do: {:via, Registry, {MiniLineage.Characters.Registry, session}}

  @impl true
  def init(session) do
    # Without this the process dies on its parent's exit signal and `terminate/2` never runs, so an
    # ordinary shutdown would discard whatever is buffered.
    Process.flag(:trap_exit, true)

    # The public id is discovered, or minted for a character that has never saved. Minting it here
    # rather than at the first save is what lets two tabs on one session agree on it.
    {id, player} = Store.load_by_session(session) || {Store.new_id(), %Player{}}

    # The narrative is no longer in the document, so the screen is refilled from the log — one
    # query, and only when the process starts.
    player = %{player | last_battle_narrative: BattleLog.last_for(id)}
    schedule_tick()

    state = %{
      id: id,
      session: session,
      player: player,
      expiry_timer: nil,
      viewers: %{},
      stop_timer: nil,
      dirty_since: nil,
      pending_battles: []
    }

    # Armed from the start rather than only when a viewer leaves: a process opened by a plain read
    # — a dead render, a crawler — never attaches one, and would otherwise never stop.
    {:ok, state |> publish() |> arm_expiry() |> schedule_stop()}
  end

  # -------------------------------------------------------------------- calls

  @impl true
  def handle_call(:character_id, _from, state), do: {:reply, state.id, state}

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

    {:reply, :ok, publish(state)}
  end

  # ------------------------------------------------------------------- infos

  @impl true
  def handle_info(:tick, state) do
    schedule_tick()

    {:noreply, state |> backstop() |> on_timer(&Player.process_regen_tick/1)}
  end

  def handle_info(:expiry, state) do
    # The sweep itself lives in run/2; this firing exists purely to make it happen on time.
    {:noreply, on_timer(%{state | expiry_timer: nil}, &{&1, :ok})}
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    viewers = Map.delete(state.viewers, ref)
    state = publish(%{state | viewers: viewers})

    {:noreply, if(map_size(viewers) == 0, do: schedule_stop(state), else: state)}
  end

  def handle_info(:stop_if_idle, %{viewers: viewers} = state) when map_size(viewers) == 0,
    do: {:stop, :normal, state}

  def handle_info(:stop_if_idle, state), do: {:noreply, %{state | stop_timer: nil}}

  @impl true
  def terminate(_reason, state), do: flush_pending(state)

  # ------------------------------------------------------------------- core

  # Neither timer has anything to do for a visitor who has not created a character: nothing to
  # regenerate, no effects to expire, and no health for the tick log to describe. Both keep
  # running, because the character may yet be created in here.
  defp on_timer(state, fun) do
    if Player.started?(state.player) do
      {_result, state} = run(state, fun, log: true)
      state
    else
      state
    end
  end

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

    changed? = before != player
    if opts[:log], do: TickLog.write(state.id, player, health_before, expired, changed?)

    if changed? do
      # Decided BEFORE the stamp is applied, or the stamp — which is not buffered — would itself
      # make every tick look like an action.
      acted? = flush?(before, player)
      player = if acted?, do: %{player | last_action_at: Clock.now_ms()}, else: player

      # Always broadcast: a viewer must see the tick whether or not it was worth a write.
      broadcast(state.session, player, state.id)

      state = log_battle(%{state | player: player}, before, player)

      {result, arm_expiry(if(acted?, do: persist(state), else: mark(state)))}
    else
      {result, state}
    end
  end

  # Anything outside @buffered is the player's own doing, and is written before they see the
  # result. It is also what dates a run in the Halls: `updated_at` moves whenever the row is
  # written, which a regenerating tick and a closing tab both do, and neither is something anybody
  # did.
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

  defp mark(%{dirty_since: nil} = state), do: %{state | dirty_since: Clock.now_ms()}
  defp mark(state), do: state

  # Never raises. Once there is a buffer, letting a database error kill the process would take the
  # buffer with it — so a failure keeps the state dirty and the next flush carries it.
  defp persist(state) do
    Store.save(state.id, state.session, state.player, state.pending_battles)
    Board.character_changed()

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

  defp sync(player) do
    if Player.started?(player) do
      {player, _changed} = Player.sync_zone_auras(player)
      player
    else
      player
    end
  end

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

  # Which character this process is, and whether anyone is watching it. Kept in the registry entry
  # so presence is one in-memory read rather than a message to every character.
  defp publish(state) do
    watched? = map_size(state.viewers) > 0

    Registry.update_value(MiniLineage.Characters.Registry, state.session, fn _ ->
      {state.id, watched?}
    end)

    Board.presence_changed()

    state
  end

  @doc false
  def broadcast(session, player, character_id),
    do:
      Phoenix.PubSub.broadcast(
        MiniLineage.PubSub,
        "character:#{session}",
        {:character_updated, player, character_id}
      )
end
