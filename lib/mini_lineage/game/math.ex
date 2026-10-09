defmodule MiniLineage.Game.Math do
  @moduledoc """
  JS number semantics are reproduced deliberately: `js_round/1` rounds halves toward +infinity, and
  `roll_chance/1` short-circuits at both ends WITHOUT drawing — a chance of exactly 0 or 100 consumes
  no randomness, so a seeded stream keeps its draw order.
  """
  alias MiniLineage.Game.{Rng, Rules}

  def random_int(min, max), do: Kernel.floor(Rng.random() * (max - min + 1)) + min

  def random_element(list), do: Enum.at(list, random_int(0, length(list) - 1))

  def roll_chance(chance) when chance <= 0, do: false
  def roll_chance(chance) when chance >= 100, do: true
  def roll_chance(chance), do: Rng.random() * 100 <= chance

  # Rules §12.
  def xp_for_level(level) when level <= 1, do: 0
  def xp_for_level(level), do: Rules.experience(level)

  def level_for_xp(xp), do: climb(1, xp)

  defp climb(level, xp) do
    if not max_level?(level) and xp_for_level(level + 1) <= xp,
      do: climb(level + 1, xp),
      else: level
  end

  def max_level?(level), do: level >= Rules.max_level()

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

  @doc "`Math.round`: halves go toward +infinity, unlike Elixir's round/1 which goes away from zero."
  def js_round(x), do: Kernel.floor(x + 0.5)
end
