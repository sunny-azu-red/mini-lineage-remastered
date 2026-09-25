defmodule MiniLineage.Characters.Sweeper do
  @moduledoc """
  Takes the session off characters nobody has played in a while.

  What it sweeps is the session, not the character: an abandoned run has still been played, so it
  keeps its place in the Halls and gives up only the secret that ties it to a browser. Nothing is
  deleted, and a visitor who never chose a race was never written at all.
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

    # A retired run reads as missing in the Halls, which only a refresh can show.
    if retired > 0 do
      MiniLineage.Board.character_changed()

      Logger.info(
        "retired #{retired} character(s) idle for over #{Store.ttl_hours()}h onto the board"
      )
    end

    retired
  end

  defp schedule, do: Process.send_after(self(), :sweep, @every_ms)
end
