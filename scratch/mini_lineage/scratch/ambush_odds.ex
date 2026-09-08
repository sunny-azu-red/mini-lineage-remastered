defmodule MiniLineage.Scratch.AmbushOdds do
  @moduledoc "Port of scratch/check_ambush_odds.ts — does each race ambush at its advertised rate?"
  import MiniLineage.Scratch.Report
  alias MiniLineage.Game.{Constants, Math}

  def run(iterations \\ 1_000_000) do
    IO.puts("\n--- Ambush Probability Simulation ---")
    IO.puts("Sample Size: #{num(iterations)} rolls per race\n")

    IO.puts(
      "#{pad("Race", 12)} | #{pad("Target %", 10)} | #{pad("Actual %", 10)} | #{pad("Deviation", 10)}"
    )

    IO.puts(rule())

    for race <- Constants.races() do
      hits = Enum.count(1..iterations, fn _ -> Math.ambush_chance?(race.ambush_chance) end)
      actual = hits / iterations * 100

      IO.puts(
        "#{pad(race.label, 12)} | #{pad(fixed(race.ambush_chance, 2), 10)} | " <>
          "#{pad(fixed(actual, 2), 10)} | #{signed(actual - race.ambush_chance, 4)}%"
      )
    end

    IO.puts("\nSimulation complete.")
  end
end
