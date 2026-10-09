defmodule MiniLineage.Game.Formulas do
  @moduledoc """
  The base layer's formulas, exactly as `docs/rules.md` writes them and in its order; each names its
  section. Pure but for the two rolls in §13, which draw through `Math` so a test can pin them.
  """
  alias MiniLineage.Game.{Math, Rules}

  # The caps of §9 and §10.
  @caps %{critical: 50, magic_critical: 20, atk_spd: 1500, cast_spd: 1999}
  def caps, do: @caps

  # §4
  def bonus(attr, value) do
    {growth, pivot} = Rules.bonus_curve(attr)
    Float.round(:math.pow(growth, (value |> max(1) |> min(99)) - pivot), 2)
  end

  # §5
  def level_bonus(level), do: (level + 89) / 100

  # §6
  def grown({start, gain, growth}, level),
    do: start + gain * (level - 1) + growth * (level - 1) * (level - 2) / 2

  def max_hp(grown, con), do: trunc(grown * bonus(:con, con))
  def max_mp(grown, men), do: trunc(grown * bonus(:men, men))

  # §7
  def p_atk(power, str, level), do: power * bonus(:str, str) * level_bonus(level)

  def m_atk(magic, int, level),
    do: magic * :math.pow(bonus(:int, int), 2) * :math.pow(level_bonus(level), 2)

  def p_def(body, level), do: body * level_bonus(level)
  def m_def(mind, men, level), do: mind * bonus(:men, men) * level_bonus(level)

  # §8
  def accuracy(dex, level), do: round(:math.sqrt(dex) * 6 + level)
  def evasion(dex, level), do: accuracy(dex, level)

  # §9
  def critical(dex), do: min(4 * bonus(:dex, dex), @caps.critical)
  def magic_critical(wit), do: min(0.8 * bonus(:wit, wit), @caps.magic_critical)

  # §10
  def atk_spd(dex), do: min(trunc(300 * bonus(:dex, dex)), @caps.atk_spd)
  def cast_spd(wit), do: min(trunc(333 * bonus(:wit, wit)), @caps.cast_spd)
  def blows_per_round(atk_spd), do: atk_spd / 300
  def casts_per_round(cast_spd), do: cast_spd / 333

  # §11, per 3-second tick out of combat.
  def hp_regen(level, con) do
    base = if level < 11, do: 1.5 + level / 20, else: 1.4 + level / 10
    base * level_bonus(level) * bonus(:con, con) * 3
  end

  def mp_regen(level, men), do: (0.87 + 0.03 * level) * level_bonus(level) * bonus(:men, men) * 3

  # §13
  def hit_chance(accuracy, evasion), do: (88 + 2 * (accuracy - evasion)) |> max(28) |> min(98)
  def hit?(chance), do: Math.roll_chance(chance)

  def damage_spread, do: 1 + Math.random_int(-10, 10) / 100

  def physical_damage(p_atk, p_def, opts \\ []) do
    damage = 70 * p_atk / p_def * critical_times(opts, 2) * Keyword.get(opts, :spread, 1.0)
    max(damage, 1.0)
  end

  def magic_damage(m_atk, m_def, power, opts \\ []) do
    max(91 * power * :math.sqrt(m_atk) / m_def * critical_times(opts, 4), 1.0)
  end

  defp critical_times(opts, times),
    do: if(Keyword.get(opts, :critical, false), do: times, else: 1)
end
