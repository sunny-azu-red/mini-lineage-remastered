defmodule MiniLineage.Game.PurchaseGuardTest do
  @moduledoc """
  The purchase boundary. The reference enforced this with a Zod schema before any handler ran;
  here `Actions.purchase/3` is the only gate, so it has to reject the same things.
  """
  use ExUnit.Case, async: true

  alias MiniLineage.Game.{Actions, Constants, Player}

  defp rich do
    {player, _} = Player.initialize(%Player{}, Constants.race(0), "Buyer")
    %{player | adena: 5_000_000, weapon_id: 3, armor_id: 3}
  end

  test "refuses the starting weapon and armor, which are never for sale" do
    # They cost nothing, so without this a player could downgrade for free.
    for {type, slot} <- [{"weapon", :weapon_id}, {"armor", :armor_id}] do
      {player, result} = Actions.purchase(rich(), type, 0)

      assert {:error, :invalid, _} = result
      assert Map.get(player, slot) == 3
    end
  end

  test "refuses anything that is not a number" do
    for hostile <- ["", "1; DROP TABLE characters", "abc", "1.5", " 1", nil] do
      assert {_player, {:error, :invalid, _}} = Actions.purchase(rich(), "weapon", hostile)
    end
  end

  test "refuses an out-of-range id, in both directions" do
    for id <- [-1, 6, 99, 1_000_000] do
      assert {_player, {:error, :invalid, _}} = Actions.purchase(rich(), "weapon", id)
    end
  end

  test "refuses an unknown item type rather than falling through to food" do
    assert {_player, {:error, :invalid, _}} = Actions.purchase(rich(), "trinket", 0)
    assert {_player, {:error, :invalid, _}} = Actions.purchase(rich(), "__proto__", 0)
  end

  test "still allows every genuinely purchasable item" do
    for id <- 1..5, do: assert({_p, {:ok, %{}}} = Actions.purchase(rich(), "weapon", id))
    for id <- 1..5, do: assert({_p, {:ok, %{}}} = Actions.purchase(rich(), "armor", id))
    for id <- 0..4, do: assert({_p, {:ok, %{}}} = Actions.purchase(rich(), "food", id))
  end

  test "accepts the string form a browser actually sends" do
    assert {player, {:ok, %{}}} = Actions.purchase(rich(), "weapon", "5")
    assert player.weapon_id == 5
  end
end
