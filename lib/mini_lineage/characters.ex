defmodule MiniLineage.Characters do
  @moduledoc """
  The way in to a character. Every read and write goes through the character's own process, so
  state survives a disconnect and no two actions can interleave.

  A process is addressed by the SESSION — the secret in the cookie — because that is what a
  browser has. The character's public id lives inside the process and never comes back out here.
  """
  alias MiniLineage.Board
  alias MiniLineage.Characters.{Server, Store}

  defdelegate new_session_id(), to: Store

  @doc """
  Ends the run this browser was playing and hands it a fresh character. The old row keeps its id
  and its place on the board, and gives up only its session — which the browser keeps, because it
  names the browser rather than the run.
  """
  def archive(session) do
    # Read before it is given up: after the archive, this session names the NEXT character, and a
    # broadcast about the run just retired would go out on the new run's topic.
    retired = character_id(session)

    # Stopped first, so `terminate/2` writes the final state while the row is still its own.
    stop_process(session)
    Store.archive(session)

    # Starts the next character, and tells any other tab that this one is no longer the old run.
    player = snapshot(session)
    Server.broadcast(session, player, character_id(session))

    # And whoever is reading the run that was left behind. A retired run is a different page — no
    # session holds it, so nothing walks with it — and nothing else would ever tell them: its
    # process is gone, so it will never broadcast again.
    Phoenix.PubSub.broadcast(
      MiniLineage.PubSub,
      record_topic(retired),
      {:record_retired, retired}
    )

    Board.character_changed()

    player
  end

  @doc """
  Applies `fun` inside the character's process. `fun` takes a player and returns `{player, result}`;
  this returns `{result, player}` — the character as the action left it, so nothing has to ask again.
  """
  def mutate(id, fun), do: call(id, {:mutate, fun})

  def snapshot(id), do: call(id, :snapshot)

  @doc "This session's character's PUBLIC id — what the board links to. Safe to render."
  def character_id(session), do: call(session, :character_id)

  @doc "The public ids of characters somebody has open right now. In memory; never touches the database."
  def online do
    MiniLineage.Characters.Registry
    |> Registry.select([{{:_, :_, {:"$1", true}}, [], [:"$1"]}])
    |> MapSet.new()
  end

  @doc "Registers a viewer. The process stops shortly after its last viewer goes away."
  def attach(id, pid \\ self()), do: call(id, {:attach, pid})

  def subscribe(id), do: Phoenix.PubSub.subscribe(MiniLineage.PubSub, "character:#{id}")

  @doc """
  The topic a record is watched on. Keyed by the PUBLIC id, unlike `subscribe/1`, whose topic is
  the session — a secret, and so no way for one reader to watch another's run.
  """
  def record_topic(character_id), do: "record:#{character_id}"

  def watch_record(character_id),
    do: Phoenix.PubSub.subscribe(MiniLineage.PubSub, record_topic(character_id))

  def unwatch_record(character_id),
    do: Phoenix.PubSub.unsubscribe(MiniLineage.PubSub, record_topic(character_id))

  @doc "Stops a character's process without touching its stored row."
  def forget_process(id), do: stop_process(id)

  @doc "Forgets a character entirely, process and row. For tests: the game itself deletes nothing."
  def forget(session) do
    stop_process(session)

    case Store.load_by_session(session) do
      {id, _player} -> Store.delete(id)
      nil -> :ok
    end

    :ok
  end

  # The same race `call/3` guards: an idle character stops itself, so a pid this lookup returns may
  # already be gone by the time the stop reaches it. Asking a dead process to stop is success.
  defp stop_process(id) do
    case Registry.lookup(MiniLineage.Characters.Registry, id) do
      [{pid, _}] -> GenServer.stop(pid, :normal)
      [] -> :ok
    end
  catch
    :exit, {reason, _} when reason in [:noproc, :normal, :shutdown] -> :ok
    :exit, reason when reason in [:noproc, :normal, :shutdown] -> :ok
  end

  # An idle character stops itself and its registry entry clears asynchronously, so a looked-up pid
  # may already be gone. The retry goes through the supervisor: registering a name is handled by the
  # registry itself, behind the DOWN that clears the stale entry.
  defp call(id, message, retry? \\ true) do
    GenServer.call(if(retry?, do: server(id), else: start(id)), message)
  catch
    :exit, {reason, _} when retry? and reason in [:noproc, :normal, :shutdown] ->
      call(id, message, false)
  end

  # The registry is asked first, and only a character that is NOT running reaches the supervisor.
  # Starting one runs its `init/1` — two queries — inside the supervisor's own loop, so every other
  # player's reads and writes would queue behind it if they all went through there.
  defp server(id) do
    case Registry.lookup(MiniLineage.Characters.Registry, id) do
      [{pid, _}] -> pid
      [] -> start(id)
    end
  end

  defp start(id) do
    case DynamicSupervisor.start_child(MiniLineage.Characters.Supervisor, {Server, id}) do
      {:ok, pid} ->
        pid

      # Two callers raced to start the same character; the other one won.
      {:error, {:already_started, pid}} ->
        pid

      # Anything else is the character's own `init/1` having raised. Without this the failure
      # surfaced as a CaseClauseError here, naming this line instead of the one that broke.
      {:error, {exception, stacktrace}} when is_exception(exception) ->
        reraise(exception, stacktrace)

      {:error, reason} ->
        raise "character #{inspect(id)} could not be started: #{inspect(reason)}"
    end
  end
end
