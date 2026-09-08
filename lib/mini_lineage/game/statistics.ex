defmodule MiniLineage.Game.Statistics do
  @moduledoc """
  Fire-and-forget global counters, mirroring the reference's `void statisticsRepository.increment`.
  A no-op until the collector is running, so the rules core stays runnable with no database.
  """
  @fields ~w(total_adena total_adena_generated total_adena_spent total_ambushes total_armors_bought
             total_battles total_critical_hits total_damage_blocked total_deaths total_enemies_killed
             total_food_bought total_hp_healed total_hp_lost total_hp_regen total_levels_gained
             total_players total_players_cheated total_players_suicided total_weapons_bought
             total_xp_gained)a

  def fields, do: @fields

  def increment(field, amount \\ 1) when field in @fields do
    case Process.whereis(__MODULE__.Collector) do
      nil -> :ok
      pid -> send(pid, {:increment, field, amount})
    end

    :ok
  end
end
