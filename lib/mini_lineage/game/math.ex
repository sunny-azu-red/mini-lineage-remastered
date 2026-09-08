defmodule MiniLineage.Game.Math do
  @moduledoc """
  Port of math.service.ts. JS number semantics are reproduced deliberately: `js_round/1` rounds
  halves toward +infinity, and `roll_chance/1` short-circuits at both ends WITHOUT drawing — an
  ambush risk of exactly 0 consumes no randomness, which the golden master's draw order depends on.
  """
  alias MiniLineage.Game.{Constants, Rng}

  def random_int(min, max), do: Kernel.floor(Rng.random() * (max - min + 1)) + min

  def random_element(list), do: Enum.at(list, random_int(0, length(list) - 1))

  def roll_chance(chance) when chance <= 0, do: false
  def roll_chance(chance) when chance >= 100, do: true
  def roll_chance(chance), do: Rng.random() * 100 <= chance

  # Distinct names (not aliases) so each roll reads as its own decision at the call site.
  def crit_chance?(chance), do: roll_chance(chance)
  def ambush_chance?(chance), do: roll_chance(chance)

  def ambush_enemy_count(enemies_killed, divisor \\ 4),
    do: max(1, Kernel.floor(enemies_killed / divisor))

  # hp
  def low_health_threshold(max_hp), do: Kernel.floor(max_hp * Constants.low_health_threshold())
  def low_health?(health, max_hp), do: health > 0 and health <= low_health_threshold(max_hp)

  # xp and levels
  def xp_for_level(level) when level <= 1, do: 0
  def xp_for_level(level), do: js_round(130 * :math.pow(level, 2) + 130 * level)

  def level_for_xp(xp), do: climb(1, xp)

  defp climb(level, xp) do
    if not max_level?(level) and xp_for_level(level + 1) <= xp,
      do: climb(level + 1, xp),
      else: level
  end

  def max_level?(level), do: level >= Constants.max_level()

  def percentage(value, total, precision \\ 0)
  def percentage(_value, total, _precision) when total <= 0, do: 0

  def percentage(value, total, precision) do
    percent = max(0, min(100, value / total * 100))
    factor = :math.pow(10, precision)

    js_round(percent * factor) / factor
  end

  def xp_progress(xp) do
    level = level_for_xp(xp)

    if max_level?(level) do
      %{current: 0, required: 0, percent: 100}
    else
      current = xp - xp_for_level(level)
      required = xp_for_level(level + 1) - xp_for_level(level)

      %{current: current, required: required, percent: percentage(current, required, 1)}
    end
  end

  def xp_needed_to_level_up(xp) do
    level = level_for_xp(xp)

    if max_level?(level), do: 0, else: xp_for_level(level + 1) - xp
  end

  def level_up?(old_xp, new_xp), do: level_for_xp(new_xp) > level_for_xp(old_xp)

  # battle scaling
  def enemy_count_range(attack, min_mult \\ 0.3, max_mult \\ 0.6),
    do: %{
      min: max(1, Kernel.floor(attack * min_mult)),
      max: max(2, Kernel.floor(attack * max_mult))
    }

  def danger_level(attack, multiplier \\ 0.6), do: Kernel.floor(attack * multiplier)

  @doc "Sub-linear so stacking armor never reaches invincibility."
  def damage_blocked(defense, exponent \\ 0.95, multiplier \\ 0.8),
    do: max(1, Kernel.floor(:math.pow(defense, exponent) * multiplier))

  def base_xp_gained(attack, exponent \\ 1.5, multiplier \\ 0.8),
    do: Kernel.floor(:math.pow(attack, exponent) * multiplier)

  def base_adena_gained(attack, exponent \\ 2.65, multiplier \\ 0.05),
    do: Kernel.floor(:math.pow(attack, exponent) * multiplier)

  @doc "`Math.round`: halves go toward +infinity, unlike Elixir's round/1 which goes away from zero."
  def js_round(x), do: Kernel.floor(x + 0.5)
end
