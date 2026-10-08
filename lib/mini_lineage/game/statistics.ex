defmodule MiniLineage.Game.Statistics do
  @moduledoc """
  Fire-and-forget global counters. A no-op until the collector is running, so the rules core stays
  runnable with no database.
  """
  @fields ~w(total_adena total_adena_generated total_adena_spent total_ambushes total_armors_bought
             total_battles total_critical_hits total_damage_blocked total_deaths total_enemies_killed
             total_food_bought total_hp_healed total_hp_lost total_hp_regen total_levels_gained
             total_players total_players_cheated total_weapons_bought
             total_xp_gained)a

  def fields, do: @fields

  @doc """
  Counts a DEED unless the run is disqualified: the Tome tells no cheat's battles. The
  census (births and deaths) is not a deed and goes through `increment/2`, ungated.
  """
  def increment_for(player, field, amount \\ 1)
  def increment_for(%{cheated: true}, _field, _amount), do: :ok
  def increment_for(_player, field, amount), do: increment(field, amount)

  def increment(field, amount \\ 1)

  # Nothing moved, so nothing is sent: a zero would still arm a push of unchanged totals.
  def increment(_field, 0), do: :ok

  def increment(field, amount) when field in @fields do
    case Process.whereis(__MODULE__.Collector) do
      nil -> :ok
      pid -> send(pid, {:increment, field, amount})
    end

    :ok
  end
end
