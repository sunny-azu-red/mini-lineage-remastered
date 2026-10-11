defmodule MiniLineage.Game.TrainerTest do
  @moduledoc """
  Rules §25 as an action on a character: a line is learned only from the trainers of its own
  village, once its level is reached, the level before it known, and its SP earned. Pure.
  """
  use ExUnit.Case, async: true

  alias MiniLineage.Game.{Actions, Clock, Constants, Math, Player}

  setup do
    Clock.put_now(~U[2026-07-01 09:00:00Z])
    :ok
  end

  defp human(level, sp) do
    {player, _} = Player.initialize(%Player{}, Constants.race(0), :fighter, "Pupil")
    %{player | experience: Math.xp_for_level(level), sp: sp}
  end

  test "a new character knows its first skill at level 1, and what its trainer teaches free" do
    assert human(1, 0).skills == %{"Power Strike" => 1}

    {orc, _} = Player.initialize(%Player{}, Constants.race(1), :mystic, "Pupil")
    assert orc.skills == %{"Chill Flame" => 1, "Soul Cry" => 1}
  end

  test "a line is learned for its SP, once its level is reached" do
    {player, {:ok, _}} = Actions.learn(human(5, 100), "Power Strike", 2)

    assert player.skills["Power Strike"] == 2
    assert player.sp == 50
  end

  test "and refused too soon, out of order, without the SP, or away from home" do
    assert {_, {:error, :too_soon, _}} = Actions.learn(human(4, 1_000), "Power Strike", 2)
    assert {_, {:error, :out_of_order, _}} = Actions.learn(human(5, 1_000), "Power Strike", 3)
    assert {_, {:error, :no_sp, _}} = Actions.learn(human(5, 49), "Power Strike", 2)
    assert {_, {:error, :no_lesson, _}} = Actions.learn(human(20, 9_999), "Wind Strike", 2)

    away = %{human(5, 1_000) | location: "gludio"}
    assert {_, {:error, :no_trainer, _}} = Actions.learn(away, "Power Strike", 2)

    elsewhere = %{human(5, 1_000) | location: "elven-village"}
    assert {_, {:error, :no_trainer, _}} = Actions.learn(elsewhere, "Power Strike", 2)
  end

  test "a new skill starts from nothing" do
    {player, {:ok, _}} = Actions.learn(human(5, 1_000), "Mortal Blow", 1)
    assert player.skills["Mortal Blow"] == 1
  end

  test "the hunt fights with the level of the first skill the character knows" do
    {player, _} = Actions.learn(human(5, 100), "Power Strike", 2)
    assert Player.first_skill(player).power == 27
    assert Player.first_skill(human(1, 0)).power == 25
  end
end
