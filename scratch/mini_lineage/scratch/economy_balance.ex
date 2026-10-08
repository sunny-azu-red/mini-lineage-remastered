defmodule MiniLineage.Scratch.EconomyBalance do
  @moduledoc "Can a career fund every piece of gear in it?"
  import MiniLineage.Scratch.Report
  alias MiniLineage.Game.{Constants, Math}
  alias MiniLineage.Scratch.EconomyBalance.Runner

  def run do
    for race <- Constants.races(), do: check(race)
  end

  defp check(race) do
    gear_cost =
      Enum.sum(Enum.map(Constants.weapons(), & &1.cost)) +
        Enum.sum(Enum.map(Constants.armors(), & &1.cost))

    IO.puts("\n--- Economy Balance Check: #{race.emoji} #{race.label} ---")
    IO.puts("Total cost of all Gear: 🪙 #{num(gear_cost)} Adena")
    IO.puts(rule())

    earned = Runner.earnings_to_max_level(race)
    surplus = earned - gear_cost

    IO.puts(
      "Total Adena Earned at Lvl #{MiniLineage.Game.Rules.max_level()}: 🪙 #{num(Math.js_round(earned))}"
    )

    IO.puts("Financial Status: #{if surplus >= 0, do: "✅ AFFORDABLE", else: "❌ NOT AFFORDABLE"}")

    if surplus >= 0,
      do: IO.puts("Surplus (for Food/Potions): 🪙 #{num(Math.js_round(surplus))} Adena"),
      else: IO.puts("Shortfall: 🪙 #{num(abs(Math.js_round(surplus)))} Adena")
  end
end
