defmodule MiniLineage.Characters.Server do
  @moduledoc """
  One process per character. The mailbox serialises, so concurrent actions cannot interleave. It
  owns the regeneration tick, and stops a little after its last viewer goes.
  """
  use GenServer, restart: :transient

  alias MiniLineage.Characters.{Store, TickLog}
  alias MiniLineage.Game.Player
  require Logger

  # How long the process outlives its last viewer before stopping. Its buffer is flushed on the way.
  @idle_grace_ms Application.compile_env!(:mini_lineage, :character_idle_grace_ms)
  @tick_interval_ms Application.compile_env!(:mini_lineage, :tick_interval_ms)

  # The passage of time; everything else is something the player did, and is written before they
  # are told it worked. Derived from the struct, not declared per call site, which could forget.
  @buffered ~w(health mp)a

  # A connected but idle player triggers neither an action nor a stop, so nothing would write.
  @backstop_ms 60_000

  def start_link(session), do: GenServer.start_link(__MODULE__, session, name: via(session))

  def via(session), do: {:via, Registry, {MiniLineage.Characters.Registry, session}}

  @impl true
  def init(session) do
    # Without this the process dies on its parent's exit signal and `terminate/2` never runs, so an
    # ordinary shutdown would discard whatever is buffered.
    Process.flag(:trap_exit, true)

    # Minted here rather than at the first save, so two tabs on one session agree on the id.
    {id, player} = Store.load_by_session(session) || {Store.new_id(), %Player{}}

    schedule_tick()

    state = %{
      id: id,
      session: session,
      player: player,
      viewers: %{},
      stop_timer: nil,
      dirty_since: nil
    }

    # Armed from the start: a process opened by a plain read never attaches a viewer, and would
    # otherwise never stop.
    {:ok, schedule_stop(state)}
  end

  # -------------------------------------------------------------------- calls

  @impl true
  def handle_call({:mutate, fun}, _from, state) do
    {result, state} = run(state, fun)

    {:reply, {result, state.player}, state}
  end

  def handle_call(:snapshot, _from, state), do: {:reply, state.player, state}

  def handle_call({:attach, pid}, _from, state) do
    ref = Process.monitor(pid)
    state = cancel_stop(%{state | viewers: Map.put(state.viewers, ref, pid)})

    {:reply, :ok, presence(state, "joined")}
  end

  # ------------------------------------------------------------------- infos

  @impl true
  def handle_info(:tick, state) do
    schedule_tick()
    state = backstop(state)

    if Player.started?(state.player) do
      before = state.player
      {healed?, state} = run(state, &Player.regenerate/1)
      TickLog.write(state.id, state.player, before, healed?)

      {:noreply, state}
    else
      {:noreply, state}
    end
  end

  # The reason says how the tab went: a clean close, or a socket found dead only by its heartbeat.
  def handle_info({:DOWN, ref, :process, _pid, reason}, state) do
    viewers = Map.delete(state.viewers, ref)
    state = presence(%{state | viewers: viewers}, "left: #{inspect(reason)}")

    {:noreply, if(map_size(viewers) == 0, do: schedule_stop(state), else: state)}
  end

  def handle_info(:stop_if_idle, %{viewers: viewers} = state) when map_size(viewers) == 0,
    do: {:stop, :normal, state}

  def handle_info(:stop_if_idle, state), do: {:noreply, %{state | stop_timer: nil}}

  @impl true
  def terminate(_reason, %{dirty_since: nil}), do: :ok
  def terminate(_reason, state), do: persist(state)

  # ------------------------------------------------------------------- core

  # mutate -> persist or buffer -> broadcast. Whether anything changed is decided by comparing the
  # struct, never by a handler remembering to say so.
  defp run(state, fun) do
    before = state.player
    {player, result} = fun.(before)

    if player == before do
      {result, state}
    else
      state = %{state | player: player}
      state = if acted?(before, player), do: persist(state), else: mark(state)

      # After the write, so whoever reads the push finds what it announces.
      broadcast(state.session, state.player)

      {result, state}
    end
  end

  # Anything outside @buffered is the player's own doing.
  defp acted?(before, now) do
    before
    |> Map.from_struct()
    |> Enum.any?(fn {field, was} -> field not in @buffered and Map.get(now, field) != was end)
  end

  defp backstop(%{dirty_since: nil} = state), do: state

  defp backstop(state),
    do: if(now_ms() - state.dirty_since >= @backstop_ms, do: persist(state), else: state)

  # Monotonic: only ever compared with itself, so a wall-clock jump cannot fire the backstop.
  defp now_ms, do: System.monotonic_time(:millisecond)

  defp mark(%{dirty_since: nil} = state), do: %{state | dirty_since: now_ms()}
  defp mark(state), do: state

  # Never raises: a database error would take the buffer with the process, so a failure keeps the
  # state dirty and the next flush carries it.
  defp persist(state) do
    Store.save(state.id, state.session, state.player)

    %{state | dirty_since: nil}
  rescue
    error ->
      Logger.error("💾 character #{state.id} failed to persist, still buffered: #{inspect(error)}")

      mark(state)
  end

  defp schedule_tick, do: Process.send_after(self(), :tick, @tick_interval_ms)

  defp schedule_stop(state),
    do: %{state | stop_timer: Process.send_after(self(), :stop_if_idle, @idle_grace_ms)}

  defp cancel_stop(%{stop_timer: nil} = state), do: state

  defp cancel_stop(state) do
    Process.cancel_timer(state.stop_timer)

    %{state | stop_timer: nil}
  end

  # `[PRESENCE:<id>] Online | 2 viewers (joined)`, in the tick log's shape and at its level.
  defp presence(state, why) do
    viewers = map_size(state.viewers)

    Logger.debug(fn ->
      "[PRESENCE:#{String.slice(state.id, 0, 7)}] #{if viewers > 0, do: "Online", else: "Offline"} | " <>
        "#{viewers} viewer#{if viewers == 1, do: "", else: "s"} (#{why})"
    end)

    state
  end

  @doc false
  # The session's topic is the browser's own: its key is a secret, so nobody watches anybody else.
  def broadcast(session, player) do
    Phoenix.PubSub.broadcast(
      MiniLineage.PubSub,
      "character:#{session}",
      {:character_updated, player}
    )
  end
end
