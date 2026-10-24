defmodule MiniLineage.Characters do
  @moduledoc """
  The way in to a character. Every read and write goes through the character's own process, so
  state survives a disconnect and no two actions can interleave.

  A process is addressed by the SESSION — the secret in the cookie — because that is what a
  browser has. The character's public id lives inside the process.
  """
  alias MiniLineage.Characters.{Server, Store}

  defdelegate new_session_id(), to: Store

  @doc """
  Applies `fun` inside the character's process. `fun` takes a player and returns `{player, result}`;
  this returns `{result, player}` — the character as the action left it, so nothing has to ask again.
  """
  def mutate(session, fun), do: call(session, {:mutate, fun})

  def snapshot(session), do: call(session, :snapshot)

  @doc "Rules §20: the last fight the session's run fought on a ground, or nil."
  def last_fight(session, ground), do: call(session, {:last_fight, ground})

  @doc "The public id of the run a session is playing: never the session, which is the secret."
  def character_id(session), do: call(session, :character_id)

  @doc "The public ids of the runs someone has open right now, read from the registry."
  def online do
    MiniLineage.Characters.Registry
    |> Registry.select([{{:_, :_, {:"$1", true}}, [], [:"$1"]}])
    |> MapSet.new()
  end

  @doc "Registers a viewer. The process stops shortly after its last viewer goes away."
  def attach(session, pid \\ self()), do: call(session, {:attach, pid})

  def subscribe(session), do: Phoenix.PubSub.subscribe(MiniLineage.PubSub, "character:#{session}")

  @doc "Stops a character's process without touching its stored row."
  def forget_process(session), do: stop_process(session)

  @doc """
  Forgets a character entirely, process and row, for tests and the debug build's `quit`. A release
  deletes nothing.
  """
  def forget(session) do
    stop_process(session)

    case Store.load_by_session(session) do
      # The process's stop only re-stamps the board's dots, which would keep the row standing.
      {id, _player} ->
        Store.delete(id)
        MiniLineage.Board.character_changed()

      nil ->
        :ok
    end

    :ok
  end

  # The same race `call/3` guards: an idle character stops itself, so a pid this lookup returns may
  # already be gone by the time the stop reaches it. Asking a dead process to stop is success.
  defp stop_process(session) do
    case Registry.lookup(MiniLineage.Characters.Registry, session) do
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
  defp call(session, message, retry? \\ true) do
    GenServer.call(if(retry?, do: server(session), else: start(session)), message)
  catch
    :exit, {reason, _} when retry? and reason in [:noproc, :normal, :shutdown] ->
      call(session, message, false)
  end

  # Only a character that is NOT running reaches the supervisor: starting one runs `init/1`'s two
  # queries inside the supervisor's own loop, and everyone else would queue behind it.
  defp server(session) do
    case Registry.lookup(MiniLineage.Characters.Registry, session) do
      [{pid, _}] -> pid
      [] -> start(session)
    end
  end

  defp start(session) do
    case DynamicSupervisor.start_child(MiniLineage.Characters.Supervisor, {Server, session}) do
      {:ok, pid} ->
        pid

      # Two callers raced to start the same character; the other one won.
      {:error, {:already_started, pid}} ->
        pid

      # The character's own `init/1` raised; reraised so the trace names the line that broke.
      {:error, {exception, stacktrace}} when is_exception(exception) ->
        reraise(exception, stacktrace)

      {:error, reason} ->
        raise "a character could not be started: #{inspect(reason)}"
    end
  end
end
