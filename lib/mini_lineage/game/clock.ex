defmodule MiniLineage.Game.Clock do
  @moduledoc """
  The game's one source of the time, in UTC, and rules §15's night. A process can pin the time for
  itself, and a pin is found through `$callers` too, so one set in a test reaches the LiveView that
  test starts. A character's own process is not a caller: pin it from inside, through `mutate`.
  """
  @key :mini_lineage_clock

  @doc "Holds the time still at `now` for the calling process."
  def put_now(%DateTime{} = now), do: Process.put(@key, now)

  def now do
    Enum.find_value([self() | Process.get(:"$callers", [])], &pinned/1) || DateTime.utc_now()
  end

  defp pinned(pid) when pid == self(), do: Process.get(@key)

  defp pinned(pid) do
    case Process.info(pid, :dictionary) do
      {:dictionary, dictionary} -> with({@key, now} <- List.keyfind(dictionary, @key, 0), do: now)
      nil -> nil
    end
  end

  @doc "Rules §15: from 22:00 to 06:00 in the game's zone."
  def night?(now \\ now()) do
    %{hour: hour} = DateTime.shift_zone!(now, zone())
    hour >= 22 or hour < 6
  end

  @doc "The next dusk or dawn after `now`, in UTC. Built in the zone, so a DST day moves it."
  def next_boundary(now \\ now()) do
    today = now |> DateTime.shift_zone!(zone()) |> DateTime.to_date()

    for day <- [today, Date.add(today, 1)], time <- [~T[06:00:00], ~T[22:00:00]] do
      day |> DateTime.new!(time, zone()) |> DateTime.shift_zone!("Etc/UTC")
    end
    |> Enum.find(&(DateTime.compare(&1, now) == :gt))
  end

  defp zone, do: Application.fetch_env!(:mini_lineage, :time_zone)
end
