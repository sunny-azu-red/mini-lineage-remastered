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
  def mutate(id, fun), do: call(id, {:mutate, fun})

  def snapshot(id), do: call(id, :snapshot)

  @doc "Registers a viewer. The process stops shortly after its last viewer goes away."
  def attach(id, pid \\ self()), do: call(id, {:attach, pid})

  def subscribe(id), do: Phoenix.PubSub.subscribe(MiniLineage.PubSub, "character:#{id}")

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

  # Only a character that is NOT running reaches the supervisor: starting one runs `init/1`'s two
  # queries inside the supervisor's own loop, and everyone else would queue behind it.
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

      # The character's own `init/1` raised; reraised so the trace names the line that broke.
      {:error, {exception, stacktrace}} when is_exception(exception) ->
        reraise(exception, stacktrace)

      {:error, reason} ->
        raise "character #{inspect(id)} could not be started: #{inspect(reason)}"
    end
  end
end
