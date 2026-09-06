defmodule MiniLineage.Game.CheatTest do
  @moduledoc "The Konami cheat: silent activation, and a permanent bar from the highscores."
  use ExUnit.Case, async: true

  alias MiniLineage.Game.{Actions, Constants, Player}

  defp living do
    {player, _flash} = Player.initialize(%Player{}, Constants.race(0), "Cheater")
    %{player | health: 10}
  end

  test "marks the player, applies the mark and snaps health to the boosted maximum" do
    {player, {:ok, nil}} = Actions.cheat(living())

    assert player.cheated
    assert Enum.any?(player.effects, &(&1.id == "konami_cheat"))
    assert player.health == Player.stats(player).max_health
    assert player.health > 10
  end

  test "is a silent no-op for a visitor with no character" do
    {player, {:ok, nil}} = Actions.cheat(%Player{})

    refute player.cheated
    assert player.effects == []
  end

  test "is a silent no-op for the dead" do
    {player, {:ok, nil}} = Actions.cheat(%{living() | dead: true})

    refute player.cheated
  end

  test "bars the highscores for good" do
    {player, _} = Actions.cheat(living())
    {_player, result} = Actions.submit_highscore(%{player | dead: true})

    assert {:error, :ineligible, _message} = result
  end
end
