defmodule MiniLineage.Game.MotherTreeTest do
  @moduledoc """
  Rules §16's Blessing of the Mother Tree: an Elf in Elven Village rests half again as fast, and
  nobody else does, neither an Elf elsewhere nor anybody else beneath it. The aura carries the
  rate, so the tooltip and the tick cannot disagree. Pinned to the day, so night adds nothing.
  """
  use ExUnit.Case, async: true

  alias MiniLineage.Game.{Clock, Constants, Player, Snapshot}

  setup do
    Clock.put_now(~U[2026-07-01 09:00:00Z])
    :ok
  end

  # Wounded and drained, so both bars are short and the rates show.
  defp tired(race_id, location) do
    {player, _} = Player.initialize(%Player{}, Constants.race(race_id), :fighter, "Rester")
    %{player | location: location, health: 1, mp: 0}
  end

  defp blessed?(player), do: Enum.any?(Player.auras(player), &(&1.id == "mother_tree"))
  defp rates(player), do: Enum.find(Player.auras(player), &(&1.id == "regenerating")).rates

  test "an Elf beneath the Mother Tree rests half again as fast, and shows why" do
    elf = tired(2, "elven-village")

    assert blessed?(elf)
    assert rates(elf) == [hp_regen: 8, mp_regen: 5]
  end

  test "and the tick heals exactly what the aura says" do
    elf = tired(2, "elven-village")
    {healed, true} = Player.regenerate(elf)

    assert {healed.health - elf.health, healed.mp - elf.mp} == {8, 5}
  end

  test "an Elf anywhere else rests at the ordinary rate" do
    for location <- ~w(gludio dion) do
      elf = tired(2, location)

      refute blessed?(elf), location
      assert rates(elf) == [hp_regen: 5, mp_regen: 3], location
    end
  end

  test "and no other race is blessed in Elven Village, resting there as it would anywhere" do
    for race_id <- [0, 1, 3] do
      visitor = tired(race_id, "elven-village")

      refute blessed?(visitor), "race #{race_id}"
      assert rates(visitor) == rates(tired(race_id, "gludio")), "race #{race_id}"
    end
  end

  test "the header names the blessing and what it does" do
    tooltip =
      Snapshot.build(tired(2, "elven-village")).effects
      |> Enum.find(&(&1.id == "mother_tree"))
      |> Map.fetch!(:tooltip)

    assert tooltip == "Blessing of the Mother Tree (×1.5 HP regen, ×1.5 MP regen)"
  end
end
