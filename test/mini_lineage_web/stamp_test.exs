defmodule MiniLineageWeb.StampTest do
  @moduledoc """
  `<.stamp>` and the sentences that carry it. A stamp is an age inside the cap and a date past it,
  and only a date takes "on", so the prose around it names no preposition and reads either way.
  The clock is pinned per process, which is what lets this run async.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias MiniLineage.Game.{Clock, Constants, Player, Snapshot}
  alias MiniLineageWeb.{Controls, Screens.Record}

  @now ~U[2026-09-29 15:10:00Z]

  setup do
    Clock.put_now(DateTime.to_unix(@now, :millisecond))
    :ok
  end

  defp stamp(opts), do: render_component(&Controls.stamp/1, opts)

  describe "a stamp" do
    test "says an age, and in a sentence spells it out" do
      at = DateTime.add(@now, -4, :minute)

      assert stamp(at: at, form: :short) =~ ">4m ago</time>"
      assert stamp(at: at) =~ ">4 minutes ago</time>"
    end

    test "names the date past the cap, with an \"on\" and a time only where it asks for them" do
      at = ~U[2026-09-12 08:00:00Z]

      assert stamp(at: at) =~ ">12 September</time>"
      assert stamp(at: at, on: true) =~ ">on 12 September</time>"
      assert stamp(at: at, form: :short, time: true) =~ ">12 Sep, 8:00 am</time>"

      assert stamp(at: at, on: true, time: true, at_time: true) =~
               ">on 12 September at 8:00 am</time>"
    end

    test "and an age takes none of them" do
      at = DateTime.add(@now, -4, :minute)

      assert stamp(at: at, on: true, time: true, at_time: true) =~ ">4 minutes ago</time>"
    end

    # The hook reads these to repaint what the server drew, so they are the label's whole recipe.
    test "carries what the hook needs to say it again" do
      html = stamp(at: ~U[2026-09-12 08:00:00Z], form: :short)

      assert html =~ ~s(datetime="2026-09-12T08:00:00Z")
      assert html =~ ~s(title="12 Sep 2026, 8:00 am")
      assert html =~ ~s(data-form="short")
      refute html =~ ~r/data-(on|time|at-time)/

      spoken = stamp(at: @now, on: true, time: true, at_time: true)

      for flag <- ~w(data-on data-time data-at-time),
          do: assert(spoken =~ ~r/<time[^>]* #{flag}[\s>]/)
    end

    test "and its container, the hook with the server's clock and the cap" do
      assert Controls.stamps() == [
               "phx-hook": "Stamps",
               "data-now": DateTime.to_unix(@now, :millisecond),
               "data-cap-ms": :timer.hours(24 * 7)
             ]
    end
  end

  describe "the road" do
    defp living do
      {player, _} = Player.initialize(%Player{}, Constants.race(1), "Hero")
      player
    end

    defp road(player, entry, mine) do
      render_component(&Record.record/1,
        view: Snapshot.build(player),
        catalog: Snapshot.catalog(),
        entry: entry,
        mine: mine
      )
      |> then(&Regex.run(~r|<span id="record-road"[^>]*>(.*?)</span>|s, &1))
      |> List.last()
      |> String.replace(~r/<[^>]+>/, "")
      |> String.replace(~r/\s+/, " ")
      |> String.trim()
    end

    @recent %{
      inserted_at: ~U[2026-09-26 15:10:00Z],
      last_seen_at: ~U[2026-09-29 15:06:00Z],
      active: true
    }
    @old %{
      inserted_at: ~U[2025-12-31 23:59:00Z],
      last_seen_at: ~U[2026-09-02 09:05:00Z],
      active: true
    }

    test "reads with ages, to you and about them" do
      assert road(living(), @recent, true) ==
               "The road opened beneath your feet 3 days ago and last carried you 4 minutes ago."

      assert road(living(), @recent, false) ==
               "The road opened beneath their feet 3 days ago and last carried them 4 minutes ago."
    end

    test "and with dates, each taking its own \"on\" and \"at\"" do
      assert road(living(), @old, true) ==
               "The road opened beneath your feet on 31 December 2025 at 11:59 pm and last carried you on 2 September at 9:05 am."
    end

    test "and with one of each" do
      mixed = %{@old | inserted_at: ~U[2026-09-02 09:05:00Z], last_seen_at: @now}

      assert road(living(), mixed, false) ==
               "The road opened beneath their feet on 2 September at 9:05 am and last carried them just now."
    end

    test "closes over the fallen" do
      assert road(Player.kill(living()), @recent, true) ==
               "The road opened beneath your feet 3 days ago and closed over you 4 minutes ago."

      assert road(Player.kill(living()), @old, false) ==
               "The road opened beneath their feet on 31 December 2025 at 11:59 pm and closed over them on 2 September at 9:05 am."
    end

    test "and swallows the missing, after they were last sighted" do
      missing = %{@old | active: false}

      assert road(living(), missing, true) ==
               "The road opened beneath your feet on 31 December 2025 at 11:59 pm and swallowed you after you were last sighted on 2 September at 9:05 am."

      assert road(living(), %{@recent | active: false}, false) ==
               "The road opened beneath their feet 3 days ago and swallowed them after they were last sighted 4 minutes ago."
    end
  end
end
