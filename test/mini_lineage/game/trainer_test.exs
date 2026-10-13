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

  defp new(race_id, path) do
    {player, _} = Player.initialize(%Player{}, Constants.race(race_id), path, "Pupil")
    player
  end

  # A Human Fighter that bought its Power Strike at level 1.
  defp human(level, sp) do
    player = new(0, :fighter)
    %{player | experience: Math.xp_for_level(level), sp: sp, skills: %{"Power Strike" => 1}}
  end

  test "a new Fighter knows nothing and buys its first skill at level 1 for 10 SP" do
    fighter = new(0, :fighter)
    assert fighter.skills == %{}

    assert {_, {:error, :no_sp, _}} = Actions.learn(%{fighter | sp: 9}, "Power Strike", 1)
    {fighter, {:ok, _}} = Actions.learn(%{fighter | sp: 10}, "Power Strike", 1)
    assert {fighter.skills, fighter.sp} == {%{"Power Strike" => 1}, 0}
  end

  test "a new Mystic knows its first spell, and buys what else level 1 offers for 50 SP" do
    orc = new(1, :mystic)
    assert orc.skills == %{"Chill Flame" => 1}

    assert {_, {:error, :no_sp, _}} = Actions.learn(%{orc | sp: 49}, "Soul Cry", 1)
    {orc, {:ok, _}} = Actions.learn(%{orc | sp: 50}, "Soul Cry", 1)
    assert {orc.skills, orc.sp} == {%{"Chill Flame" => 1, "Soul Cry" => 1}, 0}
  end

  test "a line is learned for its SP, once its level is reached" do
    {player, {:ok, _}} = Actions.learn(human(5, 100), "Power Strike", 2)

    assert player.skills["Power Strike"] == 2
    assert player.sp == 0
  end

  test "and refused too soon, out of order, without the SP, or away from home" do
    assert {_, {:error, :too_soon, _}} = Actions.learn(human(4, 1_000), "Power Strike", 2)
    assert {_, {:error, :out_of_order, _}} = Actions.learn(human(10, 9_999), "Power Strike", 3)
    assert {_, {:error, :no_sp, _}} = Actions.learn(human(5, 99), "Power Strike", 2)
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
    assert Player.first_skill(player).power == 30
    assert Player.first_skill(human(1, 0)).power == 25
  end
end
