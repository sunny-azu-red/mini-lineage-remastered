defmodule MiniLineage.Characters.Sweeper do
  @moduledoc """
  Takes the session off characters nobody has played in a while.

  What it sweeps is the session, not the character: an abandoned run has still been played, so it
  keeps its place in the Halls and gives up only the secret that ties it to a browser. The one
  thing it does delete is a visitor who never chose a race, which is a row about nobody.
  """
  use GenServer

  require Logger

  alias MiniLineage.Characters.Store

  @every_ms :timer.hours(1)

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @doc "Sweeps now and reports how many were retired. For tests and for a hand at the console."
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
    retired = Store.retire_idle()

    if retired > 0,
      do:
        Logger.info(
          "retired #{retired} character(s) idle for over #{Store.ttl_hours()}h onto the board"
        )

    retired
  end

  defp schedule, do: Process.send_after(self(), :sweep, @every_ms)
end
