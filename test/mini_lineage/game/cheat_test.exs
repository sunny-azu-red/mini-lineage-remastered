defmodule MiniLineage.Game.CheatTest do
  @moduledoc "The Konami cheat: silent activation, and a permanent bar from the Halls of Champions."
  use ExUnit.Case, async: true

  alias MiniLineage.Game.{Actions, Constants, Player, Snapshot, Statistics}

  defp living do
    {player, _flash} = Player.initialize(%Player{}, Constants.race(0), "Cheater")
    %{player | health: 10}
  end

  test "marks the player, applies the mark and snaps health to the boosted maximum" do
    {player, {:ok, nil}} = Actions.cheat(living())

    assert player.cheated
    assert Enum.any?(player.effects, &(&1.id == "konami_cheat"))
    assert player.health == Player.stats(player).max_health
    assert player.health > 10
  end

  test "is a silent no-op for a visitor with no character" do
    {player, {:ok, nil}} = Actions.cheat(%Player{})

    refute player.cheated
    assert player.effects == []
  end

  test "is a silent no-op for the dead" do
    {player, {:ok, nil}} = Actions.cheat(%{living() | dead: true})

    refute player.cheated
  end

  test "bars the Halls for good" do
    # Nothing is refused any more — the run is simply not ranked, and it carries the mark that says
    # so from the moment the sequence lands, alive or dead.
    {player, _} = Actions.cheat(living())

    assert Snapshot.build(player).disqualified
    assert Snapshot.build(%{player | dead: true}).disqualified
  end

  describe "what a disqualified run writes into the realm's history" do
    # The collector is a plain process that takes {:increment, field, amount}. Standing in for it
    # is how a rules test reads the counters without a database anywhere near it.
    setup do
      # The name frees itself when this test process dies, so nothing has to give it back.
      Process.register(self(), MiniLineage.Game.Statistics.Collector)

      :ok
    end

    defp counted do
      receive do
        {:increment, field, amount} -> [{field, amount} | counted()]
      after
        0 -> []
      end
    end

    test "nothing, once the cheat is on" do
      {player, _} = Actions.cheat(living())
      _ = counted()

      Statistics.increment_for(player, :total_battles)
      Statistics.increment_for(player, :total_xp_gained, 4_000)

      assert counted() == []
    end

    test "nor once a run has taken its own life" do
      player = Player.commit_suicide(living())
      _ = counted()

      Statistics.increment_for(player, :total_battles)

      assert counted() == []
    end

    test "but the census counts everyone, or souls arrive and never leave" do
      _ = counted()

      # Taking your own life is still falling, and the Tome tells the Weak Souls as a few OF the
      # fallen — a subset that outnumbers its whole is not a story anybody can read.
      Player.commit_suicide(living())

      assert {:total_deaths, 1} in counted()
    end

    test "and a heretic who dies is still one of the fallen" do
      {player, _} = Actions.cheat(living())
      _ = counted()

      Player.kill(player)

      assert {:total_deaths, 1} in counted()
    end

    test "but an honest run still writes everything it does" do
      player = living()
      # Drained first: being born is itself counted, and this is about what happens after.
      _ = counted()

      Statistics.increment_for(player, :total_battles)

      assert counted() == [{:total_battles, 1}]
    end

    test "and the disqualification itself is always counted, or nobody could be told of it" do
      _ = counted()
      {_player, _} = Actions.cheat(living())

      assert {:total_players_cheated, 1} in counted()
    end
  end
end
