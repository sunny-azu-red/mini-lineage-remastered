defmodule MiniLineage.Game.RegenAuraTest do
  @moduledoc """
  🌿 Regenerating is derived per read rather than stored, so it appears and vanishes on its own. It
  wants three things at once — the resting aura, a wound, and a positive rate — and its rate is the
  TOTAL one, so armor and food show up in the tooltip the same as ancestry does.

  Nothing was checking any of it: the aura is cosmetic, so a wrong one costs no health and no test
  went red.
  """
  use ExUnit.Case, async: true

  alias MiniLineage.Game.{Constants, Player}

  defp rested(race_id, overrides \\ %{}) do
    {player, _} = Player.initialize(%Player{}, Constants.race(race_id), "Mender")
    {player, _} = Player.sync_zone_auras(Map.merge(%{player | current_screen: "home"}, overrides))

    player
  end

  defp aura(player), do: Enum.find(Player.active_effects(player), &(&1.id == "regenerating"))

  test "a wounded Human resting shows it, at their own rate" do
    assert %{modifiers: [%{type: :regen, value: 1}]} = aura(rested(0, %{health: 10}))
  end

  test "a lineage with no regeneration never sees it" do
    # An Orc mends nothing, so there is no rate to show and nothing to promise.
    refute aura(rested(1, %{health: 10}))
  end

  test "topping up loses it the instant there is nothing left to mend" do
    refute aura(rested(2)), "a character at full health has no wound to heal"
  end

  test "standing in a combat zone loses it, wound or no wound" do
    {player, _} =
      Player.sync_zone_auras(%{rested(2, %{health: 10}) | current_screen: "battle"})

    refute aura(player)
  end

  test "the dead mend nothing" do
    refute aura(%{rested(2, %{health: 10}) | dead: true})
  end

  test "the rate is the total, not the ancestry's share of it" do
    # Eternal Aegis carries +3 regen on top of the Elf's own 3.
    assert %{modifiers: [%{type: :regen, value: 6}]} =
             aura(rested(2, %{health: 10, armor_id: 5}))
  end

  test "it is never folded back into the stats it was derived from" do
    # Counting the derived aura as a modifier would double the rate on every read.
    assert Player.stats(rested(2, %{health: 10})).regen == 3
  end

  describe "the tick that heals" do
    test "heals by exactly what the aura promises" do
      player = rested(2, %{health: 10, armor_id: 5})
      %{modifiers: [%{value: rate}]} = aura(player)

      {healed, true} = Player.process_regen_tick(player)

      assert healed.health == 10 + rate
    end

    test "and never runs where there is no aura to show for it" do
      for player <- [
            rested(1, %{health: 10}),
            rested(2),
            %{rested(2, %{health: 10}) | dead: true}
          ] do
        refute aura(player)
        assert {^player, false} = Player.process_regen_tick(player)
      end
    end

    test "stops at full rather than overshooting" do
      player = rested(2, %{health: 94})

      {healed, true} = Player.process_regen_tick(player)

      assert healed.health == Player.stats(player).max_health
    end
  end
end
