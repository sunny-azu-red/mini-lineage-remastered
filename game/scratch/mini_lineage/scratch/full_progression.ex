defmodule MiniLineage.Scratch.FullProgression do
  @moduledoc """
  Port of scratch/simulate_full_progression.ts — one character from level 1 to the cap, buying the
  next gear tier the moment it is affordable and eating whenever health drops below 40%.
  """
  import MiniLineage.Scratch.Report
  alias MiniLineage.Game.{Battle, Constants, Math, Player}

  def run do
    IO.puts("\n#{rule(54)}")
    IO.puts("    FULL LIFECYCLE SIMULATION: LEVEL 1 -> #{Constants.max_level()}")
    IO.puts(rule(54))

    for race <- Constants.races(), do: race |> lifecycle() |> print()
  end

  defp lifecycle(race) do
    player = %Player{
      name: "Player",
      race_id: race.id,
      weapon_id: 0,
      armor_id: 0,
      health: race.start_health,
      experience: 0,
      adena: race.start_adena
    }

    state = %{
      race: race,
      player: player,
      battles: 0,
      earned: 0,
      on_gear: 0,
      on_food: 0,
      meals: 0,
      deaths: 0,
      timeline: [],
      last_recorded: 1
    }

    state |> loop() |> Map.update!(:timeline, &Enum.reverse/1)
  end

  defp loop(state) do
    level = Math.level_for_xp(state.player.experience)

    if Math.max_level?(level) do
      state
    else
      state |> upgrade() |> fight() |> feed() |> record(level) |> loop()
    end
  end

  # Weapon first, then armor, each only when the very next tier is already affordable.
  defp upgrade(state) do
    state
    |> buy(:weapon_id, Enum.at(Constants.weapons(), state.player.weapon_id + 1))
    |> buy(:armor_id, Enum.at(Constants.armors(), state.player.armor_id + 1))
  end

  defp buy(state, _slot, nil), do: state

  defp buy(state, slot, item) do
    if state.player.adena >= item.cost do
      player = %{state.player | adena: state.player.adena - item.cost}

      %{
        state
        | player: Map.put(player, slot, Map.get(player, slot) + 1),
          on_gear: state.on_gear + item.cost
      }
    else
      state
    end
  end

  defp fight(state) do
    result = Battle.simulate(state.player)

    player = %{
      state.player
      | experience: state.player.experience + result.xp_gained,
        adena: state.player.adena + result.adena_gained,
        health: max(0, state.player.health - result.hp_lost)
    }

    state = %{
      state
      | player: player,
        battles: state.battles + 1,
        earned: state.earned + result.adena_gained
    }

    if player.health == 0,
      do: %{
        state
        | player: %{player | health: state.race.start_health},
          deaths: state.deaths + 1
      },
      else: state
  end

  # Health is measured against the race's base pool, not the buffed maximum, as the reference did.
  defp feed(state) do
    max_hp = state.race.start_health

    if state.player.health < max_hp * 0.4,
      do: eat(state, food_for(state.player.weapon_id), max_hp),
      else: state
  end

  defp eat(state, food, max_hp) do
    if state.player.health < max_hp * 0.8 and state.player.adena >= food.cost do
      ceiling = max_hp + food_max_health_bonus(food)

      player = %{
        state.player
        | adena: state.player.adena - food.cost,
          health: min(ceiling, state.player.health + food.stat)
      }

      eat(
        %{state | player: player, on_food: state.on_food + food.cost, meals: state.meals + 1},
        food,
        max_hp
      )
    else
      state
    end
  end

  defp food_for(weapon_id) do
    foods = Constants.foods()

    cond do
      weapon_id >= 4 -> Enum.at(foods, 4)
      weapon_id >= 3 -> Enum.at(foods, 3)
      weapon_id >= 1 -> Enum.at(foods, 2)
      true -> Enum.at(foods, 0)
    end
  end

  defp food_max_health_bonus(%{effect: key}) do
    Constants.effect(key).modifiers
    |> Enum.find_value(0, &if(&1.type == :max_health, do: &1.value))
  end

  defp food_max_health_bonus(_food), do: 0

  defp record(state, level) do
    if level != state.last_recorded and (rem(level, 10) == 0 or Math.max_level?(level)) do
      entry = %{
        level: level,
        battles: state.battles,
        adena: state.player.adena,
        weapon_id: state.player.weapon_id,
        armor_id: state.player.armor_id
      }

      %{state | timeline: [entry | state.timeline], last_recorded: level}
    else
      state
    end
  end

  defp print(report) do
    race = report.race
    IO.puts("\n--- Race: #{race.emoji} #{race.label} ---")
    IO.puts("Total Battles:        #{num(report.battles)}")
    IO.puts("Total Adena Earned:   🪙 #{num(report.earned)}")
    IO.puts("Spent on Gear:        🪙 #{num(report.on_gear)}")
    IO.puts("Spent on Food:        🪙 #{num(report.on_food)} (#{num(report.meals)} meals)")
    IO.puts("Final Surplus Adena:  🪙 #{num(report.player.adena)}")
    IO.puts("Combat Deaths:        #{report.deaths}")
    IO.puts("\nTimeline:")
    IO.puts("Level | Battles | Adena Bank | Weapon | Armor")
    IO.puts(rule(47))

    for entry <- report.timeline do
      IO.puts(
        "#{pad(entry.level, 5)} | #{pad(entry.battles, 7)} | " <>
          "🪙 #{pad(num(entry.adena), 10)} | " <>
          "#{pad(Constants.weapon(entry.weapon_id).name, 16)} | " <>
          "#{Constants.armor(entry.armor_id).name}"
      )
    end
  end
end
