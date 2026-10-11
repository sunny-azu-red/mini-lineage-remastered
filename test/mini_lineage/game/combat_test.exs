defmodule MiniLineage.Game.CombatTest do
  @moduledoc """
  Rules §11 and §20: a character on the hunting ground is in combat and does not rest, and it rests
  again only once it has been back in town for the disengaging's five seconds.
  """
  use ExUnit.Case, async: true

  alias MiniLineage.Game.{Clock, Constants, Player}

  setup do
    Clock.put_now(~U[2026-07-01 09:00:00Z])
    {player, _} = Player.initialize(%Player{}, Constants.race(0), :fighter, "Fighter")
    %{hurt: %{player | health: 10}}
  end

  test "a hurt character in town rests", %{hurt: hurt} do
    assert {%{health: health}, true} = Player.regenerate(hurt)
    assert health > 10
    assert hd(Player.auras(hurt)).id == "resting"
  end

  test "engaged, it does not, and says so", %{hurt: hurt} do
    engaged = %{hurt | combat: "engaged"}

    assert Player.regenerate(engaged) == {engaged, false}
    assert hd(Player.auras(engaged)).id == "combat"
    refute Enum.any?(Player.auras(engaged), &(&1.id == "regenerating"))
  end

  test "disengaging, it does not for five seconds, then rests and forgets it", %{hurt: hurt} do
    leaving = Player.disengage(%{hurt | combat: "engaged"})
    assert Player.regenerate(leaving) == {leaving, false}

    Clock.put_now(~U[2026-07-01 09:00:05.001Z])
    assert {%{combat: nil, health: health}, true} = Player.regenerate(leaving)
    assert health > 10
  end
end
