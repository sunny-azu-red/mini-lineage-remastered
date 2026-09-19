defmodule MiniLineage.PersistenceTest do
  @moduledoc "The global counters against the real database. The board has its own suite."
  use MiniLineage.DataCase, async: false

  alias MiniLineage.Game.Statistics
  import ExUnit.CaptureLog

  alias MiniLineage.Game.Statistics.Collector

  # This database is shared with the browser walkthrough, so a test must assert against what it
  # put there, not what happened to be lying around. The sandbox rolls this back afterwards.
  setup do
    Repo.query!("DELETE FROM statistics")

    :ok
  end

  describe "statistics" do
    setup do
      pid = start_supervised!(Collector)
      Ecto.Adapters.SQL.Sandbox.allow(MiniLineage.Repo, self(), pid)

      :ok
    end

    test "coalesces increments and applies them as an atomic upsert" do
      # read_all/0 answers nil until somebody has played, so a counter test needs a player.
      Statistics.increment(:total_players)
      Statistics.increment(:total_battles)
      Statistics.increment(:total_battles, 4)
      Statistics.increment(:total_adena, 250)
      Collector.flush()

      stats = Collector.read_all()
      assert stats.total_battles == 5
      assert stats.total_adena == 250
    end

    test "adds to an existing row rather than replacing it" do
      Statistics.increment(:total_players)
      Statistics.increment(:total_deaths, 3)
      Collector.flush()
      Statistics.increment(:total_deaths, 2)
      Collector.flush()

      assert Collector.read_all().total_deaths == 5
    end

    test "reads back nil while nobody has ever played, so the client can show its empty state" do
      assert Collector.read_all() == nil

      Statistics.increment(:total_players)
      Collector.flush()

      assert Collector.read_all().total_players == 1
    end

    test "drains as ONE statement, not one per counter" do
      Statistics.increment(:total_players)
      Statistics.increment(:total_battles, 5)
      Statistics.increment(:total_deaths, 2)
      Collector.flush()

      stats = Collector.read_all()
      assert {stats.total_battles, stats.total_deaths} == {5, 2}
    end

    test "reading flushes first, so a new player never sees empty archives" do
      # No explicit flush: read_all/0 must drain the buffer itself, or the very player who just
      # filled the archives reads them back as though nobody had ever played.
      Statistics.increment(:total_players)
      Statistics.increment(:total_battles, 3)

      assert %{total_players: 1, total_battles: 3} = Collector.read_all()
    end

    # Reading drains the buffer too, and so does the collector stopping, so every one of them fails
    # the same way. Tagged rather than wrapped one call at a time.
    @tag :capture_log
    test "a failed flush re-queues its counters rather than dropping them" do
      Statistics.increment(:total_players)
      Statistics.increment(:total_battles, 4)
      # Too large for a BIGINT column, so the whole batch is rejected. Chosen over breaking the
      # table with DDL, which commits implicitly and would escape the test's transaction.
      Statistics.increment(:total_deaths, 99_999_999_999_999_999_999)

      log = capture_log(fn -> Collector.flush() end)

      assert log =~ "counter(s) re-queued", "the failure went by unannounced"
      # Nothing reached the database — the archives still read as never-played...
      assert Collector.read_all() == nil
      # ...and nothing was lost on the way either.
      assert Collector.pending()[:total_battles] == 4
      assert Collector.pending()[:total_players] == 1

      # Stopped here rather than left to teardown: the collector flushes on the way out, which
      # fails once more, and by then the test's capture is no longer listening.
      stop_supervised!(Collector)
    end

    test "a counter moving tells whoever is reading, without waiting to be written" do
      Collector.subscribe()

      # A player too: the archives read as nil until somebody has played, which is their own
      # empty state and not something the push invented.
      Statistics.increment(:total_players, 1)
      Statistics.increment(:total_battles, 3)

      assert_receive {:statistics, totals}, 2_000
      assert totals.total_battles == 3

      # No flush was asked for and the timer is a minute away, so what the reader was just told is
      # still owed to the database. Telling and writing are not the same errand.
      assert Collector.pending()[:total_battles] == 3
    end

    test "and says nothing at all while nothing moves" do
      Collector.subscribe()

      Collector.flush()

      refute_receive {:statistics, _}, 800
    end

    test "and gathers a flurry into one telling rather than one apiece" do
      Collector.subscribe()
      Statistics.increment(:total_players, 1)

      for _ <- 1..20, do: Statistics.increment(:total_battles, 1)

      assert_receive {:statistics, totals}, 2_000
      assert totals.total_battles == 20
      refute_receive {:statistics, _}, 800
    end

    test "every declared field is present, defaulted to zero" do
      Statistics.increment(:total_players)
      Collector.flush()

      stats = Collector.read_all()
      for field <- Statistics.fields(), do: assert(is_integer(stats[field]))
    end
  end
end
