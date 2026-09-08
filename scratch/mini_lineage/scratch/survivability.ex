defmodule MiniLineage.Scratch.Survivability do
  @moduledoc """
  Port of scratch/check_survivability.ts. A battle costing more than the race's whole starting
  pool counts as a lethal risk, so this is the deadliness of one fight, not of a career.
  """
  import MiniLineage.Scratch.Report
  alias MiniLineage.Game.{Battle, Constants, Player}

  def run(iterations \\ 1_000) do
    IO.puts("\nSIMULATING COMBAT DEADLINESS...")
    check(0, 0, 0, iterations)
    check(2, 0, 0, iterations)
    check(1, 0, 0, iterations)
    check(0, 3, 3, iterations)
  end

  defp check(race_id, weapon_id, armor_id, iterations) do
    race = Constants.race(race_id)

    player = %Player{
      name: "Hero",
      race_id: race_id,
      weapon_id: weapon_id,
      armor_id: armor_id,
      health: race.start_health,
      experience: 0,
      adena: 0
    }

    results = Enum.map(1..iterations, fn _ -> Battle.simulate(player) end)
    avg_hp_lost = Enum.sum(Enum.map(results, & &1.hp_lost)) / iterations
    deaths = Enum.count(results, &(&1.hp_lost >= race.start_health))
    death_rate = deaths / iterations * 100

    IO.puts("\n--- Survivability: #{race.emoji} #{race.label} ---")
    IO.puts("Gear: Weapon(#{weapon_id}), Armor(#{armor_id})")
    IO.puts("Avg HP Lost per Battle: #{fixed(avg_hp_lost, 1)}")
    IO.puts("Lethal Risk (Death %):  #{fixed(death_rate, 2)}%")

    if death_rate > 5,
      do: IO.puts("⚠️ WARNING: High mortality rate for this gear level!"),
      else: IO.puts("✅ STABLE: Players are safe at this stage.")
  end
end
