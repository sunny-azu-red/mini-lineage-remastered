defmodule MiniLineage.Game.BalanceGoldenTest do
  @moduledoc """
  GOLDEN MASTER for game balance: 400 fights per character across four races and five seeds,
  through the real battle math, shops, level curve, ambushes and narrative draws, re-pinned when
  the Interlude player system replaced the race numbers and the level curve. One stream, so it
  also pins the ORDER randomness is consumed in; the clock is frozen because the pinned numbers
  assume no buff ever expires.
  """
  use ExUnit.Case, async: true

  alias MiniLineage.Game.{Battle, Clock, Constants, Math, Narrative, Player}
  alias MiniLineage.Test.Lcg

  @frozen_now 1_700_000_000_000

  defp play(race_id, start_seed) do
    Lcg.install(start_seed)
    Clock.put_now(@frozen_now)

    {player, _flash} =
      Player.initialize(%Player{}, Constants.race(race_id), :fighter, "Hero#{race_id}")

    {player, _} = Player.sync_zone_auras(%{player | current_screen: "home"})

    player = Enum.reduce_while(1..400, player, fn _fight, player -> fight(player) end)

    %{
      level: Math.level_for_xp(player.experience || 0),
      experience: player.experience,
      adena: player.adena,
      dead: player.dead,
      battles: player.total_battles,
      kills: player.total_enemies_killed,
      ambushes: player.total_ambushes,
      weapon_id: player.weapon_id,
      armor_id: player.armor_id
    }
  end

  defp fight(%{dead: true} = player), do: {:halt, player}

  defp fight(player) do
    # Buy the best affordable weapon and armor, then eat if badly hurt.
    player =
      player
      |> buy_best("weapon", Constants.weapons(), :weapon_id)
      |> buy_best("armor", Constants.armors(), :armor_id)
      |> maybe_eat()

    {player, _} = Player.sync_zone_auras(%{player | current_screen: "battle", ambushed: false})

    result = Battle.simulate(player)
    {player, level_up?} = Player.resolve_battle_outcome(player, result)
    result = %{result | is_level_up: level_up?}

    player = if player.dead, do: player, else: roll_ambush(player, result)

    # Spelled out in the order the old processTick() ran them, so the pinned numbers
    # cannot move. Production splits these across two mechanisms; a balance simulation wants both.
    {player, _} = Player.process_effect_expiry(player)
    {player, _} = Player.process_regen_tick(player)

    {:cont, player}
  end

  defp roll_ambush(player, result) do
    ambushed = Math.ambush_chance?(Player.stats(player).ambush_risk)

    player =
      if ambushed,
        do: %{player | ambushed: true, total_ambushes: player.total_ambushes + 1},
        else: player

    # Included because it consumes randomness — dropping it would shift the stream.
    Narrative.build_battle(player, result, ambushed)

    player
  end

  defp buy_best(player, type, list, slot) do
    (length(list) - 1)..1//-1
    |> Enum.reduce_while(player, fn id, player ->
      item = Enum.at(list, id)

      if Map.get(player, slot) != id and player.adena >= item.cost do
        {player, _result} = Player.purchase(player, type, id)
        {:halt, player}
      else
        {:cont, player}
      end
    end)
  end

  defp maybe_eat(player) do
    if player.health < Player.stats(player).max_hp / 2 do
      foods = Constants.foods()

      (length(foods) - 1)..0//-1
      |> Enum.reduce_while(player, fn id, player ->
        if player.adena >= Enum.at(foods, id).cost do
          {player, _result} = Player.purchase(player, "food", id)
          {:halt, player}
        else
          {:cont, player}
        end
      end)
    else
      player
    end
  end

  @golden [
    {"race0-seed1",
     %{
       level: 41,
       dead: false,
       experience: 60791,
       adena: 268,
       weapon_id: 1,
       armor_id: 1,
       battles: 400,
       kills: 2665,
       ambushes: 14
     }},
    {"race0-seed7",
     %{
       level: 42,
       dead: false,
       experience: 64133,
       adena: 605,
       weapon_id: 1,
       armor_id: 1,
       battles: 400,
       kills: 2767,
       ambushes: 13
     }},
    {"race0-seed42",
     %{
       level: 37,
       dead: true,
       experience: 40995,
       adena: 130,
       weapon_id: 1,
       armor_id: 1,
       battles: 267,
       kills: 1783,
       ambushes: 3
     }},
    {"race0-seed1234",
     %{
       level: 41,
       dead: false,
       experience: 62676,
       adena: 191,
       weapon_id: 1,
       armor_id: 1,
       battles: 400,
       kills: 2735,
       ambushes: 15
     }},
    {"race0-seed99999",
     %{
       level: 41,
       dead: false,
       experience: 62400,
       adena: 129,
       weapon_id: 1,
       armor_id: 1,
       battles: 400,
       kills: 2746,
       ambushes: 20
     }},
    {"race1-seed1",
     %{
       level: 41,
       dead: false,
       experience: 60547,
       adena: 251,
       weapon_id: 1,
       armor_id: 1,
       battles: 400,
       kills: 2655,
       ambushes: 47
     }},
    {"race1-seed7",
     %{
       level: 42,
       dead: false,
       experience: 63772,
       adena: 645,
       weapon_id: 1,
       armor_id: 1,
       battles: 400,
       kills: 2749,
       ambushes: 52
     }},
    {"race1-seed42",
     %{
       level: 37,
       dead: true,
       experience: 41082,
       adena: 155,
       weapon_id: 1,
       armor_id: 1,
       battles: 267,
       kills: 1783,
       ambushes: 28
     }},
    {"race1-seed1234",
     %{
       level: 41,
       dead: false,
       experience: 62218,
       adena: 265,
       weapon_id: 1,
       armor_id: 1,
       battles: 400,
       kills: 2721,
       ambushes: 43
     }},
    {"race1-seed99999",
     %{
       level: 41,
       dead: false,
       experience: 62199,
       adena: 157,
       weapon_id: 1,
       armor_id: 1,
       battles: 400,
       kills: 2740,
       ambushes: 49
     }},
    {"race2-seed1",
     %{
       level: 41,
       dead: false,
       experience: 60412,
       adena: 224,
       weapon_id: 1,
       armor_id: 1,
       battles: 400,
       kills: 2680,
       ambushes: 0
     }},
    {"race2-seed7",
     %{
       level: 41,
       dead: false,
       experience: 62393,
       adena: 247,
       weapon_id: 1,
       armor_id: 1,
       battles: 400,
       kills: 2730,
       ambushes: 0
     }},
    {"race2-seed42",
     %{
       level: 41,
       dead: false,
       experience: 61688,
       adena: 104,
       weapon_id: 1,
       armor_id: 1,
       battles: 400,
       kills: 2673,
       ambushes: 0
     }},
    {"race2-seed1234",
     %{
       level: 42,
       dead: false,
       experience: 64842,
       adena: 628,
       weapon_id: 1,
       armor_id: 1,
       battles: 400,
       kills: 2792,
       ambushes: 0
     }},
    {"race2-seed99999",
     %{
       level: 42,
       dead: false,
       experience: 65349,
       adena: 194,
       weapon_id: 1,
       armor_id: 1,
       battles: 400,
       kills: 2835,
       ambushes: 0
     }},
    {"race3-seed1",
     %{
       level: 41,
       dead: false,
       experience: 60939,
       adena: 257,
       weapon_id: 1,
       armor_id: 1,
       battles: 400,
       kills: 2668,
       ambushes: 3
     }},
    {"race3-seed7",
     %{
       level: 42,
       dead: false,
       experience: 64133,
       adena: 525,
       weapon_id: 1,
       armor_id: 1,
       battles: 400,
       kills: 2767,
       ambushes: 5
     }},
    {"race3-seed42",
     %{
       level: 37,
       dead: true,
       experience: 40995,
       adena: 170,
       weapon_id: 1,
       armor_id: 1,
       battles: 267,
       kills: 1783,
       ambushes: 0
     }},
    {"race3-seed1234",
     %{
       level: 41,
       dead: false,
       experience: 62642,
       adena: 206,
       weapon_id: 1,
       armor_id: 1,
       battles: 400,
       kills: 2727,
       ambushes: 2
     }},
    {"race3-seed99999",
     %{
       level: 41,
       dead: false,
       experience: 62400,
       adena: 119,
       weapon_id: 1,
       armor_id: 1,
       battles: 400,
       kills: 2746,
       ambushes: 5
     }}
  ]

  for {key, expected} <- @golden do
    test "#{key} plays out exactly as before" do
      [_, race_id, seed] = Regex.run(~r/^race(\d+)-seed(\d+)$/, unquote(key))

      assert play(String.to_integer(race_id), String.to_integer(seed)) ==
               unquote(Macro.escape(expected))
    end
  end
end
