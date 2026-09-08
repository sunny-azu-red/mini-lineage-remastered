defmodule MiniLineage.Characters do
  @moduledoc """
  The way in to a character. Every read and write goes through the character's own process, so
  state survives a disconnect and no two actions can interleave.
  """
  alias MiniLineage.Characters.{Server, Store}

  defdelegate new_id(), to: Store

  @doc "Applies `fun` inside the character's process. `fun` takes a player and returns `{player, result}`."
  def mutate(id, fun), do: call(id, {:mutate, fun})

  def snapshot(id), do: call(id, :snapshot)

  @doc "Registers a viewer. The process stops shortly after its last viewer goes away."
  def attach(id, pid \\ self()), do: call(id, {:attach, pid})

  def subscribe(id), do: Phoenix.PubSub.subscribe(MiniLineage.PubSub, "character:#{id}")

  @doc "Stops a character's process without touching its stored row."
  def forget_process(id), do: stop_process(id)

  @doc "Forgets a character entirely — used by tests and the expiry sweep."
  def forget(id) do
    stop_process(id)
    Store.delete(id)

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
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} -> pid
    end
  end
end
