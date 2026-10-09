defmodule MiniLineage.Game.ClockTest do
  @moduledoc """
  Rules §15's night, in the zone the game is configured for, across summer time. The game keeps
  UTC, so every instant here is written in UTC and the zone is the clock's business alone.
  """
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias MiniLineage.Game.Clock

  defp utc(iso), do: iso |> DateTime.from_iso8601() |> elem(1)
  defp local_hour(at), do: DateTime.shift_zone!(at, "Europe/Bucharest").hour

  describe "night, in Bucharest's hours" do
    test "falls at 22:00 and lifts at 06:00 in summer, three hours ahead of UTC" do
      refute Clock.night?(utc("2026-07-01T18:59:59Z"))
      assert Clock.night?(utc("2026-07-01T19:00:00Z"))
      assert Clock.night?(utc("2026-07-02T02:59:59Z"))
      refute Clock.night?(utc("2026-07-02T03:00:00Z"))
    end

    test "and in winter, two hours ahead" do
      refute Clock.night?(utc("2026-01-15T19:59:59Z"))
      assert Clock.night?(utc("2026-01-15T20:00:00Z"))
      assert Clock.night?(utc("2026-01-16T03:59:59Z"))
      refute Clock.night?(utc("2026-01-16T04:00:00Z"))
    end

    test "the next boundary is the next dusk or dawn, wherever summer time moved it" do
      assert Clock.next_boundary(utc("2026-07-01T12:00:00Z")) == utc("2026-07-01T19:00:00Z")
      assert Clock.next_boundary(utc("2026-07-01T19:00:00Z")) == utc("2026-07-02T03:00:00Z")
      # The night the clocks go back is an hour longer, and its dawn is in winter's UTC.
      assert Clock.next_boundary(utc("2026-10-24T19:00:00Z")) == utc("2026-10-25T04:00:00Z")
    end
  end

  # Within a day of a boundary, or on a day the clocks change, where a mistake would hide.
  defp instants do
    boundaries =
      for day <- [~D[2026-03-28], ~D[2026-03-29], ~D[2026-10-24], ~D[2026-10-25], ~D[2026-07-01]],
          time <- [~T[06:00:00], ~T[22:00:00]],
          do: DateTime.new!(day, time, "Europe/Bucharest") |> DateTime.to_unix()

    near =
      gen all base <- member_of(boundaries), offset <- integer(-90_000..90_000) do
        base + offset
      end

    map(one_of([near, integer(1_700_000_000..1_900_000_000)]), &DateTime.from_unix!/1)
  end

  property "the next boundary is ahead, is a dusk or a dawn, and is where night turns" do
    check all at <- instants() do
      next = Clock.next_boundary(at)

      assert DateTime.compare(next, at) == :gt
      assert local_hour(next) in [6, 22]
      assert DateTime.diff(next, at) <= 17 * 3600
      assert Clock.night?(next) != Clock.night?(DateTime.add(next, -1))
      assert Clock.night?(at) == Clock.night?(DateTime.add(next, -1))
    end
  end

  test "a pinned time is the calling process's own, and reaches what it starts" do
    pinned = utc("2026-07-01T20:00:00Z")
    Clock.put_now(pinned)

    assert Clock.now() == pinned
    assert Task.async(&Clock.now/0) |> Task.await() == pinned
    refute spawn_now() == pinned
  end

  # A process started by nobody it knows, which a character's own process is.
  defp spawn_now do
    parent = self()
    spawn(fn -> send(parent, {:now, Clock.now()}) end)
    assert_receive {:now, now}
    now
  end
end
