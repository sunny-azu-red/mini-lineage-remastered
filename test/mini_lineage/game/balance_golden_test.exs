defmodule MiniLineage.Game.BalanceGoldenTest do
  @moduledoc """
  GOLDEN MASTER for game balance: 400 fights per character across four races and five seeds,
  through the real battle math, shops, level curve and narrative draws, re-pinned when
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

    {player, _} = Player.sync_zone_auras(%{player | current_screen: "battle"})

    result = Battle.simulate(player)
    {player, level_up?} = Player.resolve_battle_outcome(player, result)
    result = %{result | is_level_up: level_up?}

    # Included because it consumes randomness, as the fight action does.
    Narrative.build_battle(player, result)

    # Spelled out in the order the old processTick() ran them, so the pinned numbers
    # cannot move. Production splits these across two mechanisms; a balance simulation wants both.
    {player, _} = Player.process_effect_expiry(player)
    {player, _} = Player.process_regen_tick(player)

    {:cont, player}
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
       experience: 59394,
       adena: 122,
       battles: 400,
       kills: 2610,
       weapon_id: 1,
       armor_id: 1
     }},
    {"race0-seed7",
     %{
       level: 18,
       dead: true,
       experience: 2151,
       adena: 37,
       battles: 37,
       kills: 116,
       weapon_id: 0,
       armor_id: 0
     }},
    {"race0-seed42",
     %{
       level: 19,
       dead: true,
       experience: 2682,
       adena: 30,
       battles: 43,
       kills: 143,
       weapon_id: 0,
       armor_id: 0
     }},
    {"race0-seed1234",
     %{
       level: 17,
       dead: true,
       experience: 1790,
       adena: 30,
       battles: 32,
       kills: 96,
       weapon_id: 0,
       armor_id: 0
     }},
    {"race0-seed99999",
     %{
       level: 18,
       dead: true,
       experience: 2176,
       adena: 15,
       battles: 37,
       kills: 108,
       weapon_id: 0,
       armor_id: 0
     }},
    {"race1-seed1",
     %{
       level: 41,
       dead: false,
       experience: 59211,
       adena: 110,
       battles: 400,
       kills: 2610,
       weapon_id: 1,
       armor_id: 1
     }},
    {"race1-seed7",
     %{
       level: 18,
       dead: true,
       experience: 2093,
       adena: 36,
       battles: 36,
       kills: 112,
       weapon_id: 0,
       armor_id: 0
     }},
    {"race1-seed42",
     %{
       level: 19,
       dead: true,
       experience: 2682,
       adena: 30,
       battles: 43,
       kills: 143,
       weapon_id: 0,
       armor_id: 0
     }},
    {"race1-seed1234",
     %{
       level: 17,
       dead: true,
       experience: 1790,
       adena: 30,
       battles: 32,
       kills: 96,
       weapon_id: 0,
       armor_id: 0
     }},
    {"race1-seed99999",
     %{
       level: 18,
       dead: true,
       experience: 2176,
       adena: 15,
       battles: 37,
       kills: 108,
       weapon_id: 0,
       armor_id: 0
     }},
    {"race2-seed1",
     %{
       level: 41,
       dead: false,
       experience: 59811,
       adena: 181,
       battles: 400,
       kills: 2629,
       weapon_id: 1,
       armor_id: 1
     }},
    {"race2-seed7",
     %{
       level: 18,
       dead: true,
       experience: 2151,
       adena: 37,
       battles: 37,
       kills: 116,
       weapon_id: 0,
       armor_id: 0
     }},
    {"race2-seed42",
     %{
       level: 18,
       dead: true,
       experience: 2126,
       adena: 24,
       battles: 33,
       kills: 110,
       weapon_id: 0,
       armor_id: 0
     }},
    {"race2-seed1234",
     %{
       level: 17,
       dead: true,
       experience: 1790,
       adena: 30,
       battles: 32,
       kills: 96,
       weapon_id: 0,
       armor_id: 0
     }},
    {"race2-seed99999",
     %{
       level: 18,
       dead: true,
       experience: 2176,
       adena: 15,
       battles: 37,
       kills: 108,
       weapon_id: 0,
       armor_id: 0
     }},
    {"race3-seed1",
     %{
       level: 41,
       dead: false,
       experience: 59811,
       adena: 181,
       battles: 400,
       kills: 2629,
       weapon_id: 1,
       armor_id: 1
     }},
    {"race3-seed7",
     %{
       level: 18,
       dead: true,
       experience: 2093,
       adena: 36,
       battles: 36,
       kills: 112,
       weapon_id: 0,
       armor_id: 0
     }},
    {"race3-seed42",
     %{
       level: 18,
       dead: true,
       experience: 2126,
       adena: 24,
       battles: 33,
       kills: 110,
       weapon_id: 0,
       armor_id: 0
     }},
    {"race3-seed1234",
     %{
       level: 17,
       dead: true,
       experience: 1790,
       adena: 30,
       battles: 32,
       kills: 96,
       weapon_id: 0,
       armor_id: 0
     }},
    {"race3-seed99999",
     %{
       level: 18,
       dead: true,
       experience: 2176,
       adena: 15,
       battles: 37,
       kills: 108,
       weapon_id: 0,
       armor_id: 0
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
