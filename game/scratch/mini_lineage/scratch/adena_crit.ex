defmodule MiniLineage.Scratch.AdenaCrit do
  @moduledoc "Port of scratch/check_adena_crit.ts — how much richer a critical hit actually leaves you."
  import MiniLineage.Scratch.Report
  alias MiniLineage.Game.{Battle, Math, Player}

  def run(iterations \\ 1_000) do
    IO.puts("SIMULATING BATTLES...")
    simulate(0, 1, 1, iterations)
    simulate(0, 5, 5, iterations)
  end

  defp simulate(race_id, weapon_id, armor_id, iterations) do
    player = %Player{
      name: "Hero",
      race_id: race_id,
      weapon_id: weapon_id,
      armor_id: armor_id,
      health: 100,
      experience: 0,
      adena: 0
    }

    {crit, normal} =
      1..(iterations * 10)
      |> Enum.map(fn _ -> Battle.simulate(player) end)
      |> Enum.split_with(& &1.is_critical)

    normal_avg = average(normal)
    crit_avg = average(crit)

    IO.puts("\n--- Results for Weapon ID: #{weapon_id} ---")
    IO.puts("Sample Size: Normal(#{length(normal)}), Crit(#{length(crit)})")
    IO.puts("Avg Adena (Normal):   #{num(Math.js_round(normal_avg))}")
    IO.puts("Avg Adena (CRITICAL): #{num(Math.js_round(crit_avg))}")
    IO.puts("Actual Increase:      #{fixed((crit_avg - normal_avg) / normal_avg * 100, 2)}%")
  end

  defp average(results),
    do: Enum.sum(Enum.map(results, & &1.adena_gained)) / length(results)
end
