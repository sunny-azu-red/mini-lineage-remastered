defmodule MiniLineage.Game.ActionGuardsTest do
  @moduledoc """
  What starting a character refuses. The guards, not what a player is shown, are the boundary: a
  real browser walks the happy path every run, and what it cannot easily ask for is the malformed.
  """
  use ExUnit.Case, async: true

  alias MiniLineage.Game.{Actions, Player, Rules}

  test "is refused when one is already playing, so a second start cannot wipe the first" do
    {hero, {:ok, _}} = Actions.start(%Player{}, 1, "fighter", "Hero")
    {player, {:error, :already_started, _}} = Actions.start(hero, 0, "mystic", "Usurper")

    assert player == hero
  end

  test "refuses a race that does not exist rather than falling back to one" do
    for race_id <- [99, -1, "", "orc"] do
      assert {_player, {:error, :invalid, _}} =
               Actions.start(%Player{}, race_id, "fighter", "Hero")
    end
  end

  test "refuses a path that is not Fighter or Mystic, and never mints it as an atom" do
    for path <- ["warrior", "", nil, "FIGHTER"] do
      assert {_player, {:error, :invalid, _}} = Actions.start(%Player{}, 0, path, "Hero")
    end
  end

  test "refuses a name that is not one" do
    for name <- ["", "   ", String.duplicate("a", 21)] do
      assert {_player, {:error, :invalid, _}} = Actions.start(%Player{}, 0, "fighter", name)
    end
  end

  test "starts a Mystic as its race's Mystic set, at level 1 with full bars and no Adena" do
    {player, {:ok, _flash}} = Actions.start(%Player{}, "3", "mystic", " Hero ")
    stats = Player.stats(player)

    assert player.name == "Hero"
    assert player.path == :mystic
    assert Rules.set(player.race_id, player.path).name == "Dark Mystic"
    assert Player.level(player) == 1
    assert {player.health, player.mp} == {stats.max_hp, stats.max_mp}
    assert player.adena == 0
  end
end
