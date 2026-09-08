defmodule MiniLineage.Scratch.FoodBuff do
  @moduledoc """
  Port of scratch/simulate_food_buff.ts — does a food buff pay for itself over its own duration?

  Max-HP gain and duration are read from the effect config rather than restated, so a rebalance
  cannot leave this report quoting numbers the game no longer uses.
  """
  import MiniLineage.Scratch.Report
  alias MiniLineage.Game.{Battle, Constants, Math, Player}

  @buffed_foods [2, 3, 4]

  @gear_tiers [
    {"Tier 0: Starter", 0, 20},
    {"Tier 1: Early Game", 1, 25},
    {"Tier 2: Mid Game", 2, 30},
    {"Tier 3: Advanced", 3, 35},
    {"Tier 4: High Tier", 4, 40},
    {"Tier 5: Endgame", 5, 40}
  ]

  def run(iterations \\ 10_000) do
    IO.puts(String.duplicate("=", 72))
    IO.puts("MINI-LINEAGE FOOD BUFF DURATION & BALANCE SIMULATION")
    IO.puts("#{String.duplicate("=", 72)}\n")

    for {name, tier, bpm} <- @gear_tiers do
      weapon = Constants.weapon(tier)
      armor = Constants.armor(tier)

      IO.puts(
        "\n--- GEAR: #{name} (#{weapon.name} / #{armor.name}) (Pacing: ~#{bpm} battles/min) ---"
      )

      baseline = scenario(tier, nil, iterations)

      IO.puts(
        "Avg Income per Battle: #{baseline.avg_adena} Adena | " <>
          "Avg Damage Taken: #{baseline.avg_hp_lost} HP"
      )

      for food_id <- @buffed_foods, do: report(tier, food_id, bpm, iterations)
    end
  end

  defp report(tier, food_id, bpm, iterations) do
    food = Enum.at(Constants.foods(), food_id)
    config = Constants.effect(food.effect)
    max_hp = Enum.find_value(config.modifiers, 0, &if(&1.type == :max_health, do: &1.value))
    duration_sec = config.duration_ms / 1000

    result = scenario(tier, food, iterations)
    battles = Math.js_round(duration_sec / 60 * bpm)
    gross = battles * result.avg_adena
    cost_pct = if gross > 0, do: fixed(food.cost / gross * 100, 1), else: "N/A"

    duration =
      if duration_sec >= 60, do: "#{fixed(duration_sec / 60, 1)}m", else: "#{duration_sec}s"

    IO.puts(
      "  > #{food.name} (+#{max_hp} Max HP | Cost: #{food.cost} Adena | " <>
        "Duration: #{duration} / ~#{battles} battles):"
    )

    IO.puts(
      "     Gross: #{num(gross)} Adena | Cost: #{cost_pct}% of income | " <>
        "Net Profit: +#{num(gross - food.cost)} Adena"
    )
  end

  defp scenario(tier, food, iterations) do
    race = Constants.race(0)

    base = %Player{
      name: "SimPlayer",
      race_id: race.id,
      health: race.start_health,
      adena: 100_000,
      experience: 0,
      weapon_id: tier,
      armor_id: tier
    }

    base = if food, do: Player.apply_effect(base, Constants.effect(food.effect)), else: base
    # The reference started every battle at full health so the buff's max-HP gain was in play.
    player = %{base | health: Player.stats(base).max_health}

    totals =
      Enum.reduce(1..iterations, %{adena: 0, xp: 0, hp: 0}, fn _, acc ->
        result = Battle.simulate(player)

        %{
          adena: acc.adena + result.adena_gained,
          xp: acc.xp + result.xp_gained,
          hp: acc.hp + result.hp_lost
        }
      end)

    %{
      avg_adena: Math.js_round(totals.adena / iterations),
      avg_xp: Math.js_round(totals.xp / iterations),
      avg_hp_lost: Math.js_round(totals.hp / iterations)
    }
  end
end
