defmodule MiniLineage.Characters do
  @moduledoc """
  The way in to a character. Every read and write goes through the character's own process, so
  state survives a disconnect and no two actions can interleave.

  A process is addressed by the SESSION — the secret in the cookie — because that is what a
  browser has. The character's public id lives inside the process and never comes back out here.
  """
  alias MiniLineage.Characters.{Server, Store}

  defdelegate new_session_id(), to: Store

  @doc """
  Ends the run this browser was playing and hands it a fresh character. The old row keeps its id
  and its place on the board, and gives up only its session — which the browser keeps, because it
  names the browser rather than the run.
  """
  def archive(session) do
    # Stopped first, so `terminate/2` writes the final state while the row is still its own.
    stop_process(session)
    Store.archive(session)

    # Starts the next character, and tells any other tab that this one is no longer the old run.
    player = snapshot(session)
    Server.broadcast(session, player, character_id(session))

    player
  end

  @doc "Applies `fun` inside the character's process. `fun` takes a player and returns `{player, result}`."
  def mutate(id, fun), do: call(id, {:mutate, fun})

  def snapshot(id), do: call(id, :snapshot)

  @doc "This session's character's PUBLIC id — what the board links to. Safe to render."
  def character_id(session), do: call(session, :character_id)

  @doc "Registers a viewer. The process stops shortly after its last viewer goes away."
  def attach(id, pid \\ self()), do: call(id, {:attach, pid})

  def subscribe(id), do: Phoenix.PubSub.subscribe(MiniLineage.PubSub, "character:#{id}")

  @doc "Stops a character's process without touching its stored row."
  def forget_process(id), do: stop_process(id)

  @doc "Forgets a character entirely — used by tests and the expiry sweep."
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

  # An idle character stops itself, and its registry entry clears asynchronously — so a pid found
  # by lookup may already be gone. Retry once against a freshly started process rather than
  # surfacing that race to callers.
  defp call(id, message, retry? \\ true) do
    GenServer.call(server(id), message)
  catch
    :exit, {reason, _} when retry? and reason in [:noproc, :normal, :shutdown] ->
      call(id, message, false)
  end

  defp server(id) do
    case DynamicSupervisor.start_child(MiniLineage.Characters.Supervisor, {Server, id}) do
      {:ok, pid} ->
        pid

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
