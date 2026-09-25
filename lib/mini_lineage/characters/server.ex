defmodule MiniLineage.Characters.Server do
  @moduledoc """
  One process per character. The mailbox serialises, so concurrent actions cannot interleave. It
  owns both timers too: the 5s regeneration cadence, and one expiry timer re-armed at the earliest
  upcoming effect deadline.
  """
  use GenServer, restart: :transient

  alias MiniLineage.{CharacterLog, Board, Characters}
  alias MiniLineage.Characters.{Store, TickLog}
  require Logger

  alias MiniLineage.Game.{Clock, Constants, Narrative, Narratives, Player}

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
    player = %{player | last_battle_narrative: CharacterLog.last_for(id)}
    schedule_tick()

    state = %{
      id: id,
      session: session,
      player: player,
      expiry_timer: nil,
      viewers: %{},
      stop_timer: nil,
      lingering: false,
      dirty_since: nil,
      pending_rows: []
    }

    # Armed from the start rather than only when a viewer leaves: a process opened by a plain read
    # — a dead render, a crawler — never attaches one, and would otherwise never stop.
    {:ok, state |> publish() |> arm_expiry() |> schedule_stop()}
  end

  # -------------------------------------------------------------------- calls

  @impl true
  def handle_call(:character_id, _from, state), do: {:reply, state.id, state}

  # The player comes back with the result: it is already synced and swept, so a caller asking for it
  # again in a second call would pay for a whole second pass to be told the same thing.
  def handle_call({:mutate, fun}, _from, state) do
    {result, state} = run(state, fun)

    {:reply, {result, state.player}, state}
  end

  def handle_call(:snapshot, _from, state) do
    # A read still goes through the load-time sweep, so a stale buff is never shown as live.
    {_result, state} = run(state, &{&1, :ok})

    {:reply, state.player, state}
  end

  def handle_call({:attach, pid}, _from, state) do
    ref = Process.monitor(pid)
    state = cancel_stop(%{state | viewers: Map.put(state.viewers, ref, pid), lingering: false})

    {:reply, :ok, publish(state)}
  end

  # ------------------------------------------------------------------- infos

  @impl true
  def handle_info(:tick, state) do
    schedule_tick()

    # Nobody heals while they are away: a process kept up only for a buff to lapse must not start
    # regenerating a player who closed the tab minutes ago.
    state = backstop(state)

    {:noreply,
     if(state.lingering, do: state, else: on_timer(state, &Player.process_regen_tick/1))}
  end

  def handle_info(:expiry, state) do
    # The sweep itself lives in run/2; this firing exists purely to make it happen on time.
    state = on_timer(%{state | expiry_timer: nil}, &{&1, :ok})

    if state.lingering and not awaiting_lapse?(state.player),
      do: {:stop, :normal, state},
      else: {:noreply, state}
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    viewers = Map.delete(state.viewers, ref)
    state = publish(%{state | viewers: viewers})

    {:noreply, if(map_size(viewers) == 0, do: schedule_stop(state), else: state)}
  end

  # A buff still to lapse keeps it up until it does, so the lapse is written when it happens and
  # pushed to whoever is reading, rather than whenever the player next comes back.
  def handle_info(:stop_if_idle, %{viewers: viewers} = state) when map_size(viewers) == 0 do
    if awaiting_lapse?(state.player),
      do: {:noreply, %{state | stop_timer: nil, lingering: true}},
      else: {:stop, :normal, state}
  end

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
    if Clock.now_ms() - state.dirty_since >= @backstop_ms, do: retry(state), else: state
  end

  # Rows only wait here when a write failed. Once they land, a watcher has to hear about them.
  defp retry(state) do
    written = persist(state)

    if state.pending_rows != [] and written.pending_rows == [],
      do: broadcast(written.session, written.player, written.id, true)

    written
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
      acted? = flush?(before, player)

      # In the order they happened: a lapse was already overdue when this pass began, and a buff
      # the action brought settles after it.
      state =
        %{state | player: player}
        |> log_lapsed(expired)
        |> log_actions(before, player, expired)
        |> log_gained(before, player)

      # A row in the log is written now, whoever caused it: the log is what dates a run in the
      # Halls and on its own page, and somebody may be watching it.
      pending? = state.pending_rows != []
      state = if acted? or pending?, do: persist(state), else: mark(state)
      wrote? = pending? and state.pending_rows == []

      # Always broadcast: a viewer must see the tick whether or not it was worth a write. AFTER the
      # write, though — a record being watched answers the push by reading its chronicle back, and
      # a push that arrives first tells the reader about a fight the database does not have yet.
      broadcast(state.session, state.player, state.id, wrote?)

      {result, arm_expiry(state)}
    else
      {result, state}
    end
  end

  # Anything outside @buffered is the player's own doing, written before they see the result — and
  # what dates a run in the Halls, `updated_at` moving for a tick the backstop flushed and for a
  # tab closing, neither of which anybody did.
  defp flush?(before, now) do
    before
    |> Map.from_struct()
    |> Enum.any?(fn {field, was} -> field not in @buffered and Map.get(now, field) != was end)
  end

  # Drained AFTER `flush?/2` has been asked: clear the list first and before and now are identical,
  # so a purchase would never be written before the player is told it worked.
  #
  # It used to notice a fight by diffing `last_battle_narrative`, which cannot name a blade
  # somebody bought and, more quietly, cannot see a fight whose map repeats the last one exactly.
  defp drain_events(state, player) do
    rows = Enum.map(player.pending_events, &row_for(state.id, &1))

    %{state | player: %{player | pending_events: []}, pending_rows: state.pending_rows ++ rows}
  end

  defp row_for(id, %{kind: "fight", battle: battle}), do: CharacterLog.row(id, battle)
  defp row_for(id, %{kind: kind, line: line, at: at}), do: CharacterLog.event(id, kind, line, at)

  # What the action did, and anything it took away that no timer did — a death empties the list, a
  # meal replaces a meal. A death's losses go BEFORE the ending and are dated with it, because the
  # ending is always the chronicle's last line; a replaced meal leaves after the meal that did it.
  defp log_actions(state, before, now, expired) do
    lapsed = Enum.map(expired, & &1.id)
    held = Enum.map(now.effects, & &1.id)
    taken = deeds(Enum.reject(before.effects, &(&1.id in held or &1.id in lapsed)))

    if now.dead and not before.dead do
      at = ending_at(now.pending_events)

      state
      |> log_taken(taken, Narratives.effect_ended(), at)
      |> drain_events(now)
    else
      state
      |> drain_events(now)
      |> log_taken(taken, Narratives.effect_lapsed(), Clock.now())
    end
  end

  defp log_taken(state, taken, template, at),
    do: %{
      state
      | pending_rows:
          state.pending_rows ++ Enum.map(taken, &effect_row(state.id, template, &1, at))
    }

  # The instant the run ended, so what faded with it is dated the same and the log stays in order.
  defp ending_at(events) do
    case List.last(events) do
      %{kind: "fight", battle: %{at: at}} -> at
      %{at: at} -> at
      nil -> Clock.now()
    end
  end

  # Dated when the effect lapsed, not when this process noticed: a run that closed its tab, or a
  # process a deploy stopped, notices late, and the log would otherwise say the wrong time.
  defp log_lapsed(state, expired) do
    rows =
      Enum.map(deeds(expired), fn effect ->
        lapsed_at = Clock.to_datetime(effect.expires_at)
        effect_row(state.id, Narratives.effect_lapsed(), effect, lapsed_at)
      end)

    %{state | pending_rows: state.pending_rows ++ rows}
  end

  # Auras are not deeds: `sync_zone_auras/1` flips them on nearly every pass, and logging them would
  # drown everything else in 💤 and ⚔️.
  defp log_gained(state, before, now) do
    held = Enum.map(before.effects, & &1.id)

    rows =
      now.effects
      |> Enum.reject(&(&1.id in held))
      |> deeds()
      |> Enum.map(&effect_row(state.id, Narratives.effect_gained(), &1, Clock.now()))

    %{state | pending_rows: state.pending_rows ++ rows}
  end

  # The Cheater's Mark is left out: the heresy has a line of its own that says it better, and it
  # never lapses, so this would only ever repeat that one.
  defp awaiting_lapse?(player), do: Enum.any?(deeds(player.effects), &(&1.expires_at != nil))

  defp deeds(effects),
    do: Enum.filter(effects, &(&1.type in [:buff, :debuff] and &1.id != "konami_cheat"))

  # Stored as what the page calls it, so the chronicle can say which without reading its own HTML.
  defp effect_row(id, template, effect, at),
    do:
      CharacterLog.event(id, kind_of(effect), Narrative.build_effect_change(template, effect), at)

  defp kind_of(%{type: type}) when type in [:buff, :debuff], do: Atom.to_string(type)

  defp mark(%{dirty_since: nil} = state), do: %{state | dirty_since: Clock.now_ms()}
  defp mark(state), do: state

  # Never raises. Once there is a buffer, letting a database error kill the process would take the
  # buffer with it — so a failure keeps the state dirty and the next flush carries it.
  defp persist(state) do
    Store.save(state.id, state.session, state.player, state.pending_rows)
    Board.character_changed()

    %{state | dirty_since: nil, pending_rows: []}
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
  # Two topics for one change. The session's is the browser's own and carries what only its owner
  # may act on; the record's is keyed by the PUBLIC id, because a record is a public page and
  # anybody reading one should watch it move.
  def broadcast(session, player, character_id, wrote? \\ false) do
    Phoenix.PubSub.broadcast(
      MiniLineage.PubSub,
      "character:#{session}",
      {:character_updated, player, character_id}
    )

    Phoenix.PubSub.broadcast(
      MiniLineage.PubSub,
      Characters.record_topic(character_id),
      {:record_updated, player, character_id, wrote?}
    )
  end
end
