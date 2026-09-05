defmodule MiniLineage.Game.BalanceGoldenTest do
  @moduledoc """
  GOLDEN MASTER for game balance — a direct port of test/backend/service/balance.golden.test.ts.

  Plays 400 fights per character across all four races and five fixed RNG seeds, driving the real
  battle math, stat pipeline, shop logic, level curve, ambush rolls and narrative draws, then pins
  the resulting progression exactly. The expected values are the TypeScript reference's, unchanged.

  Because every roll runs off one deterministic stream, this also pins the ORDER in which
  randomness is consumed: adding, removing or reordering a draw anywhere in the fight path shifts
  every later roll and fails here, even when each individual function is still correct.

  The clock is frozen. The reference leaves it running and merely finishes fast enough that no buff
  ever expires — these numbers silently assume that, so we make it structural instead of lucky.
  """
  use ExUnit.Case, async: true

  alias MiniLineage.Game.{Battle, Clock, Constants, Math, Narrative, Player}
  alias MiniLineage.Test.Lcg

  @frozen_now 1_700_000_000_000

  defp play(race_id, start_seed) do
    Lcg.install(start_seed)
    Clock.put_now(@frozen_now)

    {player, _flash} =
      Player.initialize(%Player{}, Constants.race(race_id), "Hero#{race_id}")

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

    # Spelled out in the order the reference's old processTick() ran them, so the pinned numbers
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
    if player.health < Player.stats(player).max_health / 2 do
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
    {"race0-seed1", %{level: 21, experience: 60638, adena: 650, dead: false, battles: 400, kills: 2664, ambushes: 13, weapon_id: 1, armor_id: 1}},
    {"race0-seed7", %{level: 21, experience: 63968, adena: 199, dead: false, battles: 400, kills: 2744, ambushes: 16, weapon_id: 1, armor_id: 1}},
    {"race0-seed42", %{level: 21, experience: 61893, adena: 380, dead: false, battles: 400, kills: 2689, ambushes: 9, weapon_id: 1, armor_id: 1}},
    {"race0-seed1234", %{level: 21, experience: 60575, adena: 398, dead: false, battles: 400, kills: 2700, ambushes: 19, weapon_id: 1, armor_id: 1}},
    {"race0-seed99999", %{level: 21, experience: 62433, adena: 160, dead: false, battles: 400, kills: 2751, ambushes: 20, weapon_id: 1, armor_id: 1}},
    {"race1-seed1", %{level: 20, experience: 57062, adena: 300, dead: false, battles: 400, kills: 2601, ambushes: 56, weapon_id: 1, armor_id: 1}},
    {"race1-seed7", %{level: 20, experience: 55972, adena: 157, dead: false, battles: 400, kills: 2564, ambushes: 42, weapon_id: 1, armor_id: 1}},
    {"race1-seed42", %{level: 20, experience: 55627, adena: 560, dead: false, battles: 400, kills: 2567, ambushes: 57, weapon_id: 1, armor_id: 1}},
    {"race1-seed1234", %{level: 20, experience: 57063, adena: 400, dead: false, battles: 400, kills: 2602, ambushes: 54, weapon_id: 1, armor_id: 1}},
    {"race1-seed99999", %{level: 20, experience: 56957, adena: 178, dead: false, battles: 400, kills: 2577, ambushes: 49, weapon_id: 1, armor_id: 1}},
    {"race2-seed1", %{level: 22, experience: 67789, adena: 162, dead: false, battles: 400, kills: 2842, ambushes: 0, weapon_id: 1, armor_id: 1}},
    {"race2-seed7", %{level: 22, experience: 69763, adena: 481, dead: false, battles: 400, kills: 2924, ambushes: 0, weapon_id: 1, armor_id: 1}},
    {"race2-seed42", %{level: 22, experience: 66908, adena: 461, dead: false, battles: 400, kills: 2843, ambushes: 0, weapon_id: 1, armor_id: 1}},
    {"race2-seed1234", %{level: 22, experience: 69161, adena: 314, dead: false, battles: 400, kills: 2831, ambushes: 0, weapon_id: 1, armor_id: 1}},
    {"race2-seed99999", %{level: 22, experience: 66293, adena: 529, dead: false, battles: 400, kills: 2829, ambushes: 0, weapon_id: 1, armor_id: 1}},
    {"race3-seed1", %{level: 23, experience: 71882, adena: 200, dead: false, battles: 400, kills: 2944, ambushes: 1, weapon_id: 1, armor_id: 1}},
    {"race3-seed7", %{level: 23, experience: 72810, adena: 565, dead: false, battles: 400, kills: 2984, ambushes: 2, weapon_id: 1, armor_id: 1}},
    {"race3-seed42", %{level: 22, experience: 66765, adena: 788, dead: false, battles: 400, kills: 2809, ambushes: 4, weapon_id: 1, armor_id: 1}},
    {"race3-seed1234", %{level: 23, experience: 72971, adena: 871, dead: false, battles: 400, kills: 2954, ambushes: 3, weapon_id: 1, armor_id: 1}},
    {"race3-seed99999", %{level: 22, experience: 69425, adena: 272, dead: false, battles: 400, kills: 2857, ambushes: 3, weapon_id: 1, armor_id: 1}}
  ]

  for {key, expected} <- @golden do
    test "#{key} plays out exactly as before" do
      [_, race_id, seed] = Regex.run(~r/^race(\d+)-seed(\d+)$/, unquote(key))

      assert play(String.to_integer(race_id), String.to_integer(seed)) == unquote(Macro.escape(expected))
    end
  end
end
