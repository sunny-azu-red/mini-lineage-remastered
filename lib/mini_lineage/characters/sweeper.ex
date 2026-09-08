defmodule MiniLineage.Characters.Sweeper do
  @moduledoc """
  Drops characters nobody has played in a while. Without this the table only ever grows: a
  character's process stops within seconds of its last viewer leaving, and the row it left behind
  has nothing to remove it.
  """
  use GenServer

  require Logger

  alias MiniLineage.Characters.Store

  @every_ms :timer.hours(1)

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @doc "Sweeps now and reports how many went. For tests and for a hand at the console."
  def sweep_now, do: GenServer.call(__MODULE__, :sweep)

  @impl true
  def init(:ok) do
    schedule()

    {:ok, %{}}
  end

  @impl true
  def handle_info(:sweep, state) do
    sweep()
    schedule()

    {:noreply, state}
  end

  @impl true
  def handle_call(:sweep, _from, state), do: {:reply, sweep(), state}

  defp sweep do
    count = Store.sweep_expired()

    if count > 0,
      do: Logger.info("swept #{count} character(s) idle for over #{Store.ttl_hours()}h")

    count
  end

  defp schedule, do: Process.send_after(self(), :sweep, @every_ms)
end
