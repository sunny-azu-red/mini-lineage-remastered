defmodule MiniLineage.Game.HuntTest do
  @moduledoc """
  Rules §20's fight, pure: who is met, how the rounds go, and what a kill pays. Dice are pinned or
  generated, never rolled freely, so nothing here asserts on chance.
  """
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias MiniLineage.Game.{Clock, Constants, Hunt, Math, Player, Rng, Rules}

  setup do
    Clock.put_now(~U[2026-07-01 09:00:00Z])
    :ok
  end

  defp character(race_id, path, level \\ 1) do
    {player, _} = Player.initialize(%Player{}, Constants.race(race_id), path, "Hunter")
    Player.restore_fully(%{player | experience: Math.xp_for_level(level)})
  end

  defp fight(player, monster) do
    skill = Rules.first_skill(player.race_id, player.path)
    Hunt.fight(Player.stats(player), player, skill, Hunt.foe(Rules.monster(monster)))
  end

  # Dice as a cycled list of integers scaled into [0, 1), as AGENTS.md has them generated.
  defp dice(ints) do
    {:ok, agent} = Agent.start_link(fn -> ints end)

    Rng.put_source(fn ->
      Agent.get_and_update(agent, fn [n | rest] -> {n / 1_000, rest ++ [n]} end)
    end)
  end

  describe "who is met" do
    test "a monster within 2 levels of the character" do
      ladder = Rules.monsters_of(Rules.ground("obelisk-of-victory"))

      for value <- [0.0, 0.5, 0.9999] do
        Rng.put_source(fn -> value end)
        assert abs(Hunt.draw(ladder, 6).level - 6) <= 2
      end
    end

    test "or the nearest, past the top of the ladder" do
      ladder = Rules.monsters_of(Rules.ground("obelisk-of-victory"))
      Rng.put_source(fn -> 0.0 end)

      assert Hunt.draw(ladder, 40).name == "Blade Spider"
    end
  end

  describe "the rounds" do
    test "with every roll landing, a Human Fighter opens with Power Strike and finishes with blows" do
      # 0.0 lands every blow as a critical, at the spread's low end: 47, then 14 and 14.
      Rng.put_source(fn -> 0.0 end)
      result = fight(character(0, :fighter), "Young Keltir")

      assert result.foe == 0
      assert result.rounds == 3
      assert result.uses == 1
      assert result.critical
      assert result.mp == character(0, :fighter).mp - 10
    end

    test "a Mystic casts while its spell is ready, and pays for each cast" do
      Rng.put_source(fn -> 0.9999 end)
      mystic = character(0, :mystic)
      result = fight(mystic, "Elder Keltir")

      assert result.uses >= 1
      assert result.mp == mystic.mp - 9 * result.uses
    end

    test "a burn never takes the last HP, so an Orc Mystic needs its fists to finish" do
      Rng.put_source(fn -> 0.9999 end)
      result = fight(character(1, :mystic), "Young Prairie Keltir")

      # Every blow misses at 0.9999, so only the burn hurts, and it stops at 1.
      assert result.foe == 1
      assert result.rounds == Hunt.max_rounds()
    end

    test "with every blow missing, Power Strike still lands, once its reuse has run out" do
      # 58 a strike at the spread's top; 13,118ms of reuse is the 9th round.
      Rng.put_source(fn -> 0.9999 end)
      result = fight(character(0, :fighter), "Young Keltir")

      assert result.foe == 0
      assert result.uses == 2
      assert result.rounds == 9
    end
  end

  describe "the reward" do
    test "is whole up to 5 levels above, and 5/6 a level past it, at the server's rates" do
      assert Hunt.reward(:exp, 100, 6, 1) == 500
      assert Hunt.reward(:exp, 100, 7, 1) == 416
      assert Hunt.reward(:sp, 100, 8, 1) == 347
    end

    test "Adena only at its chance, and between its least and most" do
      keltir = Rules.monster("Young Keltir")
      Rng.put_source(fn -> 0.0 end)
      assert Hunt.adena(keltir) == keltir.adena_min * 20
      Rng.put_source(fn -> 0.9999 end)
      assert Hunt.adena(keltir) == 0
    end
  end

  defp sets, do: for(race <- 0..3, path <- [:fighter, :mystic], do: {race, path})

  property "a fight always ends: someone falls, or the rounds run out, and no bar goes below 0" do
    check all {race, path} <- member_of(sets()),
              level <- integer(1..20),
              ground <- member_of(Rules.grounds()),
              rolls <- list_of(integer(0..999), min_length: 1, max_length: 40),
              max_runs: 200 do
      dice(rolls)
      player = character(race, path, level)
      monster = Hunt.draw(Rules.monsters_of(ground), level)
      result = fight(player, monster.name)

      assert result.health == 0 or result.foe == 0 or result.rounds == Hunt.max_rounds()
      assert result.health >= 0 and result.foe >= 0 and result.mp >= 0
      assert result.health <= Player.stats(player).max_hp
    end
  end
end
