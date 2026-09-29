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
