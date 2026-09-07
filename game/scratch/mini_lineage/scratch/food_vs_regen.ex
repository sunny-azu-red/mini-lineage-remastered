defmodule MiniLineage.Scratch.FoodVsRegen do
  @moduledoc "Port of scratch/check_food_vs_regen.ts — buying 50 HP versus waiting for it."
  import MiniLineage.Scratch.Report
  alias MiniLineage.Game.Constants

  @target_heal 50

  def run do
    IO.puts("\n--- Healing ROI (Rest vs Food) ---")
    IO.puts("#{pad("Race", 10)} | #{pad("Food Item", 15)} | #{pad("Cost", 6)} | Wait (Ticks)")
    IO.puts(rule(55))

    for race <- Constants.races() do
      ticks =
        if race.regen == 0, do: "∞", else: to_string(ceil(@target_heal / race.regen))

      for food <- Enum.take(Constants.foods(), 3) do
        IO.puts(
          "#{pad(race.label, 10)} | #{pad(food.name, 15)} | " <>
            "#{pad(food.cost, 6)} | #{pad(ticks, 12)}"
        )
      end

      IO.puts(rule(55))
    end
  end
end
