defmodule MiniLineage.Game.ActionGuardsTest do
  @moduledoc """
  What each command refuses.

  Client-side routing decides what a player is shown; these guards decide what the server will do,
  and they are the boundary. The happy paths are walked by a real browser every run — what a
  browser cannot easily ask for is the malformed and the out-of-turn, which is what is here.
  """
  use ExUnit.Case, async: true

  alias MiniLineage.Game.{Actions, Constants, Player}

  defp hero do
    {player, _} = Player.initialize(%Player{}, Constants.race(1), "Hero")
    %{player | current_screen: "home"}
  end

  describe "starting a character" do
    test "is refused when one is already playing, so a second start cannot wipe the first" do
      {player, {:error, _, _}} = Actions.start(hero(), 0, "Usurper")

      assert player.name == "Hero"
      assert player.race_id == 1
    end

    test "refuses a race that does not exist rather than falling back to one" do
      assert {_player, {:error, :invalid, _}} = Actions.start(%Player{}, 99, "Hero")
      assert {_player, {:error, :invalid, _}} = Actions.start(%Player{}, -1, "Hero")
    end

    test "and refuses a name that is not one" do
      for name <- ["", "   "] do
        assert {_player, {:error, :invalid, _}} = Actions.start(%Player{}, 0, name), name
      end
    end

    test "but a good one starts in Town, already carrying its zone aura" do
      {player, {:ok, _flash}} = Actions.start(%Player{}, 0, "Hero")

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
