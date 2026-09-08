defmodule MiniLineage.Scratch.EconomyBalance.Runner do
  @moduledoc false
  alias MiniLineage.Game.{Battle, Math, Player}

  @doc "Fights to max level with gear tiered off the current level, returning the adena earned."
  def earnings_to_max_level(race) do
    player = %Player{
      name: "Hero",
      race_id: race.id,
      health: race.start_health,
      experience: 0,
      adena: 0
    }

    grind(player, 0)
  end

  defp grind(player, earned) do
    level = Math.level_for_xp(player.experience)

    if Math.max_level?(level) do
      earned
    else
      tier = min(5, floor(level / 15))
      result = Battle.simulate(%{player | weapon_id: tier, armor_id: tier})

      grind(
        %{player | experience: player.experience + result.xp_gained},
        earned + result.adena_gained
      )
    end
  end
end

defmodule MiniLineage.Scratch.EconomyBalance do
  @moduledoc "Port of scratch/check_economy_balance.ts — can a career fund every piece of gear in it?"
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

    IO.puts("Total Adena Earned at Lvl #{Constants.max_level()}: 🪙 #{num(Math.js_round(earned))}")

    IO.puts("Financial Status: #{if surplus >= 0, do: "✅ AFFORDABLE", else: "❌ NOT AFFORDABLE"}")

    if surplus >= 0,
      do: IO.puts("Surplus (for Food/Potions): 🪙 #{num(Math.js_round(surplus))} Adena"),
      else: IO.puts("Shortfall: 🪙 #{num(abs(Math.js_round(surplus)))} Adena")
  end
end
