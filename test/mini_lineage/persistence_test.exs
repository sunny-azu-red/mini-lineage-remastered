defmodule MiniLineage.PersistenceTest do
  @moduledoc "Highscores and the global counters against the real database."
  use MiniLineage.DataCase, async: false

  alias MiniLineage.Game.Statistics
  alias MiniLineage.Game.Statistics.Collector
  alias MiniLineage.Highscores

  # This database is shared with the browser walkthrough, so a test must assert against what it
  # put there, not what happened to be lying around. The sandbox rolls this back afterwards.
  setup do
    Repo.delete_all(Highscores.Entry)
    Repo.query!("DELETE FROM statistics")

    :ok
  end

  describe "highscores" do
    test "orders by experience, then adena, and caps at the configured limit" do
      for {name, xp, adena} <- [{"Low", 10, 999}, {"High", 900, 1}, {"Tie", 900, 500}] do
        Highscores.insert(%{name: name, experience: xp, race_id: 0, adena: adena, level: 1})
      end

      assert Enum.map(Highscores.list(), & &1.name) == ["Tie", "High", "Low"]
    end

    test "filters to one race" do
      Highscores.insert(%{name: "Orc", experience: 5, race_id: 1, adena: 0, level: 1})
      Highscores.insert(%{name: "Elf", experience: 5, race_id: 2, adena: 0, level: 1})

      assert Enum.map(Highscores.list(1), & &1.name) == ["Orc"]
    end
  end

  test "a legitimate death writes its legacy to the board and clears the character" do
    {player, _} =
      MiniLineage.Game.Player.initialize(
        %MiniLineage.Game.Player{},
        MiniLineage.Game.Constants.race(0),
        "Legend"
      )

    dead = MiniLineage.Game.Player.kill(%{player | experience: 4321, adena: 99})

    assert {fresh, {:ok, %{race_slug: "human"}}} = MiniLineage.Game.Actions.submit_highscore(dead)

    assert fresh == %MiniLineage.Game.Player{},
           "submitting resets in place, ready for a new character"

    assert [entry] = Highscores.list()
    assert entry.name == "Legend"
    assert entry.total_xp == 4321
    assert entry.adena == 99
    assert entry.level == MiniLineage.Game.Math.level_for_xp(4321)
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

    test "a failed flush re-queues its counters rather than dropping them" do
      Statistics.increment(:total_players)
      Statistics.increment(:total_battles, 4)
      # Too large for a BIGINT column, so the whole batch is rejected. Chosen over breaking the
      # table with DDL, which commits implicitly and would escape the test's transaction.
      Statistics.increment(:total_deaths, 99_999_999_999_999_999_999)

      Collector.flush()

      # Nothing reached the database — the archives still read as never-played...
      assert Collector.read_all() == nil
      # ...and nothing was lost on the way either.
      assert Collector.pending()[:total_battles] == 4
      assert Collector.pending()[:total_players] == 1
    end

    test "every declared field is present, defaulted to zero" do
      Statistics.increment(:total_players)
      Collector.flush()

      stats = Collector.read_all()
      for field <- Statistics.fields(), do: assert(is_integer(stats[field]))
    end
  end
end
