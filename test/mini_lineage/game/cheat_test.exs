defmodule MiniLineage.Game.CheatTest do
  @moduledoc "The Konami cheat: silent activation, and a permanent bar from the Halls of Champions."
  use ExUnit.Case, async: true

  alias MiniLineage.Game.{Actions, Constants, Player, Snapshot}

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

  test "bars the Halls for good" do
    # Nothing is refused any more — the run is simply not ranked, and it carries the mark that says
    # so from the moment the sequence lands, alive or dead.
    {player, _} = Actions.cheat(living())

    assert Snapshot.build(player).disqualified
    assert Snapshot.build(%{player | dead: true}).disqualified
  end
end
