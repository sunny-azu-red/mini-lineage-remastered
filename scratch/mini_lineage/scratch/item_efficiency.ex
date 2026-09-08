defmodule MiniLineage.Scratch.ItemEfficiency do
  @moduledoc "Port of scratch/check_item_efficiency.ts — adena paid per point of attack or defense."
  import MiniLineage.Scratch.Report
  alias MiniLineage.Game.Constants

  def run do
    table("Weapon Efficiency (Cost per Stat Point)", "Weapon", Constants.weapons())
    table("Armor Efficiency (Cost per Stat Point)", "Armor", Constants.armors())
  end

  defp table(title, column, items) do
    IO.puts("\n--- #{title} ---")
    IO.puts("#{pad(column, 20)} | #{pad("Stat", 6)} | #{pad("Cost", 10)} | Cost/Stat")
    IO.puts(rule(55))

    for item <- items do
      per_point = if item.cost == 0, do: 0, else: item.cost / item.stat

      IO.puts(
        "#{pad(item.name, 20)} | #{pad(item.stat, 6)} | " <>
          "#{pad(item.cost, 10)} | #{fixed(per_point, 2)}"
      )
    end
  end
end
