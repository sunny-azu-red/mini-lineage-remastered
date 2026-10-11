defmodule MiniLineage.Game.ShopTest do
  @moduledoc """
  Rules §23 and §24 as actions on a character: what a village shop sells and refuses, what it pays
  back, and what putting a piece on takes off. Pure, so no process and no dice.
  """
  use ExUnit.Case, async: true

  alias MiniLineage.Game.{Actions, Clock, Constants, Player, Rules, Shop}

  setup do
    Clock.put_now(~U[2026-07-01 09:00:00Z])
    :ok
  end

  defp character(race_id \\ 0, path \\ :fighter, adena \\ 100_000) do
    {player, _} = Player.initialize(%Player{}, Constants.race(race_id), path, "Buyer")
    %{player | adena: adena}
  end

  defp carried(player, name), do: Enum.find(player.items, &(&1.name == name))
  defp worn(player), do: player |> Player.worn() |> Enum.map(& &1.name) |> Enum.sort()

  describe "buying" do
    test "costs its price, and the item is carried, not worn" do
      {player, {:ok, _}} = Actions.buy(character(), "Broadsword")

      assert player.adena == 100_000 - 12_500
      assert %{equipped: false} = carried(player, "Broadsword")
    end

    test "is refused for what the village does not sell, or the purse cannot pay" do
      assert {_, {:error, :unsold, _}} = Actions.buy(character(), "Falchion")
      assert {_, {:error, :unsold, _}} = Actions.buy(character(), "Squire's Sword")
      assert {_, {:error, :unsold, _}} = Actions.buy(character(), "Cestus")

      assert {_, {:error, :cannot_afford, _}} =
               Actions.buy(character(0, :fighter, 100), "Broadsword")
    end

    test "Orc Village's traders also sell fists" do
      orc = character(1, :fighter, 200_000)
      assert {_, {:ok, _}} = Actions.buy(orc, "Cestus")
    end

    test "is refused away from a village, and when the bag is full" do
      away = %{character() | location: "gludio"}
      assert {_, {:error, :no_shop, _}} = Actions.buy(away, "Broadsword")

      full = %{character() | items: for(_ <- 1..Rules.capacity(), do: Player.new_item("Club"))}
      assert {_, {:error, :full, _}} = Actions.buy(full, "Club")
    end
  end

  describe "selling" do
    test "pays half the price, and the item is gone" do
      {player, _} = Actions.buy(character(), "Broadsword")
      sword = carried(player, "Broadsword")
      {player, {:ok, _}} = Actions.sell(player, sword.id)

      assert player.adena == 100_000 - 12_500 + 6_250
      refute carried(player, "Broadsword")
    end

    test "is refused for something worn, or a starting kit" do
      player = character()
      assert {_, {:error, :worn, _}} = Actions.sell(player, carried(player, "Squire's Sword").id)
      assert {_, {:error, :worthless, _}} = Actions.sell(player, carried(player, "Dagger").id)
    end
  end

  describe "putting on" do
    test "a weapon the first skill cannot use is worn, with a warning" do
      player = character()
      {_, {:ok, flash}} = Actions.equip(player, carried(player, "Dagger").id)

      assert flash.type == :danger
      assert flash.text =~ "Power Strike needs a sword or a blunt weapon"

      {_, {:ok, flash}} = Actions.equip(player, carried(player, "Squire's Sword").id)
      assert flash.type == :info
    end

    test "a weapon takes the last one off, which stays carried" do
      player = character()
      {player, {:ok, _}} = Actions.equip(player, carried(player, "Dagger").id)

      assert worn(player) == ["Dagger", "Squire's Pants", "Squire's Shirt"]
      assert carried(player, "Squire's Sword")
    end

    test "a two-handed weapon takes the shield off, and a shield the two-handed weapon" do
      {player, _} = Actions.buy(character(), "Small Shield")
      {player, _} = Actions.buy(player, "Short Bow")
      {player, _} = Actions.equip(player, carried(player, "Small Shield").id)
      assert "Small Shield" in worn(player)

      {player, _} = Actions.equip(player, carried(player, "Short Bow").id)
      assert "Short Bow" in worn(player)
      refute "Small Shield" in worn(player)

      {player, _} = Actions.equip(player, carried(player, "Small Shield").id)
      refute "Short Bow" in worn(player)
    end

    test "a second necklace takes the first one's place" do
      player =
        Enum.reduce(["Necklace of Magic", "Necklace of Knowledge"], character(), fn name, p ->
          {p, _} = Actions.buy(p, name)
          {p, _} = Actions.equip(p, carried(p, name).id)
          p
        end)

      assert for(item <- Player.worn(player), item.slot == :necklace, do: item.name) ==
               ["Necklace of Knowledge"]
    end

    test "destroying takes something carried away for good, and nothing worn" do
      player = character()
      {player, {:ok, _}} = Actions.destroy(player, carried(player, "Dagger").id)
      refute carried(player, "Dagger")

      assert {_, {:error, :worn_destroy, _}} =
               Actions.destroy(player, carried(player, "Squire's Sword").id)
    end

    test "taking off a robe lowers Max MP, and MP with it" do
      mystic = Player.restore_fully(character(0, :mystic))
      tunic = carried(mystic, "Apprentice's Tunic")
      {bare, {:ok, _}} = Actions.unequip(mystic, tunic.id)

      assert Player.stats(bare).max_mp == Player.stats(mystic).max_mp - 19
      assert bare.mp == Player.stats(bare).max_mp
    end
  end

  test "every village sells the same, and Orc Village fists too" do
    base = Enum.map(Rules.stock("talking-island"), & &1.name)

    for town <- ~w(elven-village dark-elf-village),
        do: assert(Enum.map(Rules.stock(town), & &1.name) == base)

    orc = Enum.map(Rules.stock("orc-village"), & &1.name)
    assert Enum.sort(orc -- base) == ["Cestus", "Fox Claw Gloves", "Iron Gloves", "Spiked Gloves"]
    assert Shop.price(Rules.item("Club")) == 768
  end
end
