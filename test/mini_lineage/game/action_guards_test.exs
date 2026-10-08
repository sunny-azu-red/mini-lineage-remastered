defmodule MiniLineage.Game.ActionGuardsTest do
  @moduledoc """
  What each command refuses. These guards, not what a player is shown, are the boundary. A real
  browser walks the happy paths every run; what it cannot easily ask for is the malformed and the
  out-of-turn, which is what is here.
  """
  use ExUnit.Case, async: true

  alias MiniLineage.Game.{Actions, Classes, Constants, Player}

  defp hero do
    {player, _} = Player.initialize(%Player{}, Constants.race(1), :fighter, "Hero")
    %{player | current_screen: "home"}
  end

  describe "starting a character" do
    test "is refused when one is already playing, so a second start cannot wipe the first" do
      {player, {:error, _, _}} = Actions.start(hero(), 0, "fighter", "Usurper")

      assert player.name == "Hero"
      assert player.race_id == 1
    end

    test "refuses a race that does not exist rather than falling back to one" do
      assert {_player, {:error, :invalid, _}} = Actions.start(%Player{}, 99, "fighter", "Hero")
      assert {_player, {:error, :invalid, _}} = Actions.start(%Player{}, -1, "fighter", "Hero")
    end

    test "refuses an archetype that is not Fighter or Mystic, and never mints it as an atom" do
      for archetype <- ["warrior", "", nil, "FIGHTER"] do
        assert {_player, {:error, :invalid, _}} = Actions.start(%Player{}, 0, archetype, "Hero")
      end
    end

    test "starts a Mystic as its race's Mystic class" do
      {player, {:ok, _flash}} = Actions.start(%Player{}, 3, "mystic", "Hero")

      assert Classes.get(player.class_id).name == "Dark Mystic"
      assert player.mp == Player.stats(player).max_mp
    end

    test "and refuses a name that is not one" do
      for name <- ["", "   "] do
        assert {_player, {:error, :invalid, _}} = Actions.start(%Player{}, 0, "fighter", name),
               name
      end
    end

    test "but a good one starts in Town, already carrying its zone aura" do
      {player, {:ok, _flash}} = Actions.start(%Player{}, 0, "fighter", "Hero")

      assert player.current_screen == "home"

      assert Enum.any?(player.effects, &(&1.id == "resting")),
             "a fresh character rendered auraless"
    end
  end

  describe "suicide" do
    test "is refused to the already dead, who have nothing left to take" do
      dead = Player.kill(hero())

      assert {_player, {:error, _, _}} = Actions.suicide(dead)
    end

    test "and marks the living as a coward, which bars the board" do
      {player, {:ok, _}} = Actions.suicide(hero())

      assert player.dead and player.coward
      assert player.current_screen == "death"
    end
  end

  describe "changing screen" do
    test "is refused to a visitor with no character to move" do
      assert {_player, {:error, _, _}} = Actions.set_screen(%Player{}, "inn")
    end

    test "and re-derives the zone aura, so resting follows you out of a fight" do
      {fighting, _} = Actions.set_screen(hero(), "battle")
      {resting, _} = Actions.set_screen(hero(), "inn")

      refute Enum.any?(fighting.effects, &(&1.id == "resting"))
      assert Enum.any?(resting.effects, &(&1.id == "resting"))
    end
  end
end
