defmodule MiniLineage.Game.ClassesAndDyesTest do
  @moduledoc """
  What the Class Master and the Symbol Maker refuse, and what they do when they do not. The
  refusals are the boundary: the screens only ever offer what these allow.
  """
  use ExUnit.Case, async: true

  alias MiniLineage.Game.{Actions, Classes, Constants, Dyes, Math, Player}

  # A Human Fighter standing in Town at `level`, with Adena to spend.
  defp human(level, overrides \\ %{}) do
    {player, _} = Player.initialize(%Player{}, Constants.race(0), :fighter, "Hero")

    Map.merge(
      %{player | current_screen: "home", experience: Math.xp_for_level(level), adena: 5_000_000},
      overrides
    )
  end

  defp kinds(player), do: Enum.map(player.pending_events, & &1.kind)

  describe "a class transfer" do
    test "takes up a calling the run's own class leads to, once its level is reached" do
      {player, {:ok, flash}} = Actions.transfer(human(20), "1")

      assert player.class_id == 1
      assert flash.text =~ "You took up the calling of a"
      assert flash.text =~ "Warrior"
      assert "class_change" in kinds(player)

      {player, {:ok, _flash}} = Actions.transfer(%{player | experience: Math.xp_for_level(40)}, 2)
      assert Classes.get(player.class_id).name == "Gladiator"
    end

    test "is refused below the calling's level" do
      assert {player, {:error, :too_low, message}} = Actions.transfer(human(19), "1")
      assert player.class_id == 0
      assert message =~ "level 20"

      {warrior, _} = Actions.transfer(human(20), "1")
      assert {_, {:error, :too_low, _}} = Actions.transfer(%{warrior | experience: 1}, "2")
    end

    test "is refused for a calling another class leads to, or none at all" do
      # Gladiator is the Warrior's, the Elven Knight the Elf's, and 999 is nobody's.
      for id <- ["2", "19", "999", "nonsense", ""] do
        assert {player, {:error, :invalid, _}} = Actions.transfer(human(40), id), id
        assert player.class_id == 0
      end
    end

    test "is refused to the dead" do
      assert {_, {:error, :dead, _}} = Actions.transfer(human(20, %{dead: true}), "1")
    end

    test "grows HP on the new table from the next level, as Interlude does" do
      {warrior, _} = Actions.transfer(human(20), "1")
      fighter = human(20)

      assert Player.stats(warrior).max_hp == Player.stats(fighter).max_hp

      at = fn player, level -> %{player | experience: Math.xp_for_level(level)} end
      assert Player.stats(at.(warrior, 21)).max_hp > Player.stats(at.(fighter, 21)).max_hp
    end
  end

  describe "a dye" do
    defp warrior(overrides \\ %{}) do
      {player, _} = Actions.transfer(human(20), "1")
      Map.merge(player, overrides)
    end

    test "is drawn into a free slot, paid for, and moves the attributes it names" do
      dye = Dyes.get(1)
      before = warrior()

      {player, {:ok, %{type: :success, text: text}}} = Actions.draw_dye(before, "1")

      assert player.dyes == [1]
      assert player.adena == before.adena - Dyes.cost(dye)
      assert Player.stats(player).str == Player.stats(before).str + 1
      assert Player.stats(player).con == Player.stats(before).con - 3
      assert text =~ dye.name
      assert "dye" in kinds(player)
    end

    test "has no slot to go in before the first transfer" do
      assert {player, {:error, :no_slots, _}} = Actions.draw_dye(human(20), "1")
      assert player.dyes == []
    end

    test "is refused for a class it is not made for, or one that does not exist" do
      # 121 is a Greater Dye, for second classes only.
      for id <- ["121", "9999", "STR"] do
        assert {player, {:error, :invalid, _}} = Actions.draw_dye(warrior(), id), id
        assert player.dyes == []
      end
    end

    test "is refused once every slot is taken: two after the first transfer" do
      {player, _} = Actions.draw_dye(warrior(), "1")
      {player, _} = Actions.draw_dye(player, "2")

      assert {player, {:error, :slots_full, _}} = Actions.draw_dye(player, "3")
      assert player.dyes == [1, 2]
    end

    test "costs nothing when the purse cannot pay for it" do
      poor = warrior(%{adena: 10})

      assert {player, {:ok, %{type: :danger}}} = Actions.draw_dye(poor, "1")
      assert player.dyes == []
      assert player.adena == 10
    end

    test "adds at most five to any one attribute, however many are worn" do
      {player, _} = Actions.transfer(warrior(%{experience: Math.xp_for_level(40)}), "2")
      base = Player.stats(player).str

      {player, _} = Actions.draw_dye(player, "121")
      {player, _} = Actions.draw_dye(player, "133")

      assert Player.stats(player).str == base + 5
    end

    test "is washed away for the Symbol Maker's fee, freeing its slot" do
      {player, _} = Actions.draw_dye(warrior(), "1")
      {player, _} = Actions.draw_dye(player, "2")
      paid = player.adena

      {player, {:ok, %{type: :success}}} = Actions.remove_dye(player, "0")

      assert player.dyes == [2]
      assert player.adena == paid - Dyes.get(1).cancel_fee
      assert {_, {:error, :invalid, _}} = Actions.remove_dye(player, "1")
    end
  end
end
