defmodule MiniLineage.Scratch.LevelingSpeed do
  @moduledoc "Port of scratch/check_leveling_speed.ts — battles spent on each level, assuming ideal gear."
  import MiniLineage.Scratch.Report
  alias MiniLineage.Game.{Battle, Constants, Math, Player}

  def run do
    for race <- Constants.races(), do: simulate(race)
  end

  defp simulate(race) do
    IO.puts("\n--- Leveling Speed Simulation: #{race.emoji} #{race.label} ---")
    IO.puts("#{pad("Level", 6)} | #{pad("Battles", 10)} | #{pad("Total Battles", 15)}")
    IO.puts(rule(35))

    player = %Player{name: "Hero", race_id: race.id, health: race.start_health, experience: 0}
    total = climb(player, 1, 0)

    IO.puts("\nTotal battles to reach Level #{Constants.max_level()}: #{num(total)}")
  end

  defp climb(player, level, total) do
    if Math.max_level?(level) do
      total
    else
      {player, at_level} = grind_to(player, level, level + 1, 0)
      reached = Math.level_for_xp(player.experience)

      if rem(reached, 10) == 0 or Math.max_level?(reached) or reached == 2,
        do: IO.puts("#{pad(reached, 6)} | #{pad(at_level, 10)} | #{pad(total + at_level, 15)}")

      climb(player, reached, total + at_level)
    end
  end

  # Gear is tiered off the level being left behind, matching the reference's `currentLevel`.
  defp grind_to(player, from_level, target, fought) do
    if Math.level_for_xp(player.experience) >= target do
      {player, fought}
    else
      tier = min(5, floor(from_level / 15))
      result = Battle.simulate(%{player | weapon_id: tier, armor_id: tier})
      player = %{player | experience: player.experience + result.xp_gained}
      grind_to(player, from_level, target, fought + 1)
    end
  end
end
