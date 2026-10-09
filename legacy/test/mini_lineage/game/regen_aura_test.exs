defmodule MiniLineage.Game.RegenAuraTest do
  @moduledoc """
  🌿 Regenerating is derived per read rather than stored, so it appears and vanishes on its own. It
  wants the resting aura and a bar short of full, and carries a rate for each bar that is: the
  TOTAL rate, so armor shows up in it the same as the class does.
  """
  use ExUnit.Case, async: true

  alias MiniLineage.Game.{Constants, Formulas, Math, Player}

  defp rested(race_id, overrides \\ %{}) do
    {player, _} = Player.initialize(%Player{}, Constants.race(race_id), :fighter, "Mender")
    {player, _} = Player.sync_zone_auras(Map.merge(%{player | current_screen: "home"}, overrides))

    player
  end

  defp aura(player), do: Enum.find(Player.active_effects(player), &(&1.id == "regenerating"))

  test "a wounded Human Fighter resting shows it, at the rate rules §11 gives" do
    # 1.55 at level 1, × 0.90 for the level, × 1.58 for CON 43, × 3: 6.6 a tick.
    assert %{modifiers: [%{type: :hp_regen, value: 7}]} = aura(rested(0, %{health: 10}))
  end

  test "mana short of full mends alongside health, each at its own rate" do
    # MP: 0.90 at level 1, × 0.90 for the level, × 1.28 for MEN 25, × 3: 3.1 a tick.
    assert %{modifiers: [%{type: :hp_regen, value: 7}, %{type: :mp_regen, value: 3}]} =
             aura(rested(0, %{health: 10, mp: 0}))
  end

  test "topping up loses it the instant there is nothing left to mend" do
    refute aura(rested(2)), "a character at full health and mana has no wound to heal"
  end

  test "standing in a combat zone loses it, wound or no wound" do
    {player, _} =
      Player.sync_zone_auras(%{rested(2, %{health: 10}) | current_screen: "battle"})

    refute aura(player)
  end

  test "the dead mend nothing" do
    refute aura(%{rested(2, %{health: 10}) | dead: true})
  end

  test "the rate is the total, not the class's share of it" do
    # Eternal Aegis carries +3 on top of what the Elven Fighter mends unarmoured.
    own = Player.stats(rested(2)).hp_regen
    expected = Math.js_round(own + 3)

    assert %{modifiers: [%{type: :hp_regen, value: ^expected}]} =
             aura(rested(2, %{health: 10, armor_id: 5}))
  end

  test "it is never folded back into the stats it was derived from" do
    # Counting the derived aura as a modifier would double the rate on every read.
    assert Player.stats(rested(2, %{health: 10})).hp_regen == Formulas.hp_regen(1, 36)
  end

  describe "the tick that heals" do
    test "heals by exactly what the aura promises, HP and MP alike" do
      player = rested(2, %{health: 10, mp: 0, armor_id: 5})
      %{modifiers: [%{value: hp_rate}, %{value: mp_rate}]} = aura(player)

      {healed, true} = Player.process_regen_tick(player)

      assert healed.health == 10 + hp_rate
      assert healed.mp == mp_rate
    end

    test "and never runs where there is no aura to show for it" do
      {fighting, _} =
        Player.sync_zone_auras(%{rested(2, %{health: 10}) | current_screen: "battle"})

      for player <- [rested(2), fighting, %{rested(2, %{health: 10}) | dead: true}] do
        refute aura(player)
        assert {^player, false} = Player.process_regen_tick(player)
      end
    end

    test "stops at full rather than overshooting" do
      player = rested(2)
      max_hp = Player.stats(player).max_hp
      player = %{player | health: max_hp - 1}

      {healed, true} = Player.process_regen_tick(player)

      assert healed.health == max_hp
    end
  end
end
