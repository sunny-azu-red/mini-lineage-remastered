defmodule MiniLineage.Game.Math do
  @moduledoc """
  JS number semantics are reproduced deliberately: `js_round/1` rounds halves toward +infinity, and
  `roll_chance/1` short-circuits at both ends WITHOUT drawing — a chance of exactly 0 or 100 consumes
  no randomness, so a pinned source keeps its draw order.
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

  def percentage(_value, total, _precision) when total <= 0, do: 0

  def percentage(value, total, precision) do
    percent = max(0, min(100, value / total * 100))
    factor = :math.pow(10, precision)

    js_round(percent * factor) / factor
  end

  @doc "A share of the total in whole hundredths of a percent, floored: never full until it is."
  def hundredths(_value, total) when total <= 0, do: 0

  def hundredths(value, total),
    do: value |> max(0) |> Kernel.*(10_000) |> div(total) |> min(10_000)

  @doc "`Math.round`: halves go toward +infinity, unlike Elixir's round/1 which goes away from zero."
  def js_round(x), do: Kernel.floor(x + 0.5)
end
