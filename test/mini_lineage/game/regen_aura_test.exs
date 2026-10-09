defmodule MiniLineage.Game.RegenAuraTest do
  @moduledoc """
  🌿 Regenerating is derived per read rather than stored, so it appears and vanishes on its own. It
  wants a bar short of full, and carries what one tick restores to each bar that is.
  """
  use ExUnit.Case, async: true

  alias MiniLineage.Game.{Constants, Player}

  defp rested(race_id, overrides \\ %{}) do
    {player, _} = Player.initialize(%Player{}, Constants.race(race_id), :fighter, "Mender")
    Map.merge(player, overrides)
  end

  defp aura(player), do: Enum.find(Player.auras(player), &(&1.id == "regenerating"))

  test "a character is always resting, there being nothing yet to fight" do
    for player <- [rested(0), rested(0, %{health: 10})] do
      assert Enum.any?(Player.auras(player), &(&1.id == "resting"))
    end
  end

  test "a wounded Human Fighter shows it, at the rate rules §11 gives" do
    # 1.55 at level 1, × 0.90 for the level, × 1.58 for CON 43, × 3: 6.6 a tick.
    assert %{rates: [hp_regen: 7]} = aura(rested(0, %{health: 10}))
  end

  test "mana short of full mends alongside health, each at its own rate" do
    # MP: 0.90 at level 1, × 0.90 for the level, × 1.28 for MEN 25, × 3: 3.1 a tick.
    assert %{rates: [hp_regen: 7, mp_regen: 3]} = aura(rested(0, %{health: 10, mp: 0}))
  end

  test "is gone the instant there is nothing left to mend" do
    refute aura(rested(2))
  end

  describe "the tick that heals" do
    test "heals by exactly what the aura promises, HP and MP alike" do
      player = rested(2, %{health: 10, mp: 0})
      %{rates: [hp_regen: hp, mp_regen: mp]} = aura(player)

      assert {%{health: health, mp: ^mp}, true} = Player.regenerate(player)
      assert health == 10 + hp
    end

    test "and never runs where there is no aura to show for it" do
      player = rested(2)
      assert {^player, false} = Player.regenerate(player)
    end

    test "stops at full rather than overshooting" do
      player = rested(2)
      max_hp = Player.stats(player).max_hp

      assert {%{health: ^max_hp}, true} = Player.regenerate(%{player | health: max_hp - 1})
    end
  end
end
