defmodule MiniLineage.Game.EffectsTest do
  @moduledoc """
  What happens when one effect meets another.

  A meal's buff belongs to a group, and a second meal replaces the first rather than stacking — a
  player who could hold three food buffs at once would carry three times the health the balance was
  built around. The Hexed debuff has no group and so is its own case.
  """
  use ExUnit.Case, async: true

  alias MiniLineage.Game.{Constants, Player}

  defp fed(player, food_id) do
    {player, _} = Player.purchase(player, "food", food_id)
    player
  end

  defp hero do
    {player, _} = Player.initialize(%Player{}, Constants.race(1), "Hero")
    %{player | adena: 100_000, health: 1}
  end

  defp food_buffs(player), do: Enum.filter(player.effects, &(&1.group == "food"))

  describe "a meal's buff" do
    test "replaces the one before it rather than stacking" do
      # Hearty Mash then Roasted Pheasant: the top three dishes each grant a timed buff.
      player = hero() |> fed(3) |> fed(4)

      assert length(food_buffs(player)) == 1
      assert hd(food_buffs(player)).id == "gourmet_feast"
    end

    test "and replacing it does not multiply the health it grants" do
      one = hero() |> fed(3)
      two = hero() |> fed(3) |> fed(4)

      assert Player.stats(two).max_health < Player.stats(one).max_health * 2
    end

    test "even when the same dish is eaten twice" do
      player = hero() |> fed(3) |> fed(3)

      assert length(food_buffs(player)) == 1
    end

    test "while the cheapest dishes grant none at all, only health" do
      player = hero() |> fed(0)

      assert food_buffs(player) == []
    end
  end

  describe "an effect with no group" do
    test "sits alongside a food buff rather than replacing it" do
      hexed = Constants.effects().ambush_debuff
      player = hero() |> fed(4) |> Player.apply_effect(hexed)

      assert length(food_buffs(player)) == 1
      assert Enum.any?(player.effects, &(&1.id == hexed.id))
    end
  end
end
