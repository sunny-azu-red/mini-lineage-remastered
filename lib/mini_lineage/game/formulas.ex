defmodule MiniLineage.Game.Formulas do
  @moduledoc """
  Interlude's stat and combat formulas as L2J Mobius CT_0 computes them, every constant cited in
  `docs/lineage2-canon.md`. Pure: the few rolls are separate functions drawing through `Math`, so a
  formula can be tested at any value and a roll pinned by `Rng.put_source/1`. Rates the server keeps
  per mille (critical, hit) stay per mille here.
  """
  alias MiniLineage.Game.Math

  # `statBonus.xml` is these closed forms rounded to two places; outside 1..99 the table has no row.
  @bonus %{
    str: {1.036, 34.845},
    con: {1.030, 27.632},
    dex: {1.009, 19.360},
    int: {1.020, 31.375},
    wit: {1.050, 20.0},
    men: {1.010, -0.06}
  }

  @caps %{crit_rate: 500, m_crit_rate: 200, p_atk_spd: 1500, m_atk_spd: 1999, evasion: 250}

  @hit_bonus %{behind: 10, side: 5, front: 0}
  @proximity %{behind: 1.2, side: 1.1, front: 1.0}
  @positions [:front, :side, :behind]

  @posture %{sitting: 1.5, standing: 1.1, running: 0.7}

  def caps, do: @caps

  def level_mod(level), do: (level + 89) / 100

  def bonus(attr, value) do
    {base, offset} = Map.fetch!(@bonus, attr)
    Float.round(:math.pow(base, (value |> max(1) |> min(99)) - offset), 2)
  end

  # ----------------------------------------------------------- derived stats

  def p_atk(base, str, level), do: base * bonus(:str, str) * level_mod(level)

  def m_atk(base, int, level),
    do: base * :math.pow(bonus(:int, int), 2) * :math.pow(level_mod(level), 2)

  def p_def(base, level), do: base * level_mod(level)
  def m_def(base, men, level), do: base * bonus(:men, men) * level_mod(level)

  # `getMaxHp` casts to int.
  def max_hp(table_value, con), do: trunc(table_value * bonus(:con, con))
  def max_mp(table_value, men), do: trunc(table_value * bonus(:men, men))

  def accuracy(dex, level) do
    value = :math.sqrt(dex) * 6 + level
    value = if level > 77, do: value + (level - 76), else: value
    value = if level > 69, do: value + (level - 69), else: value
    round(value)
  end

  def evasion(dex, level) do
    late = if level >= 78, do: (level - 69) * 1.2, else: level - 69
    value = :math.sqrt(dex) * 6 + level + if(level >= 70, do: late, else: 0)
    min(round(value), @caps.evasion)
  end

  def crit_rate(base, dex), do: trunc(min(base * bonus(:dex, dex) * 10, @caps.crit_rate) + 0.5)

  # The cast binds to the bonus before the ×10, so WIT moves it only in whole steps of 1%.
  def m_crit_rate(base, wit), do: min(trunc(base * bonus(:wit, wit)) * 10, @caps.m_crit_rate)

  def p_atk_spd(base, dex), do: min(trunc(base * bonus(:dex, dex)), @caps.p_atk_spd)
  def m_atk_spd(base, wit), do: min(trunc(base * bonus(:wit, wit)), @caps.m_atk_spd)

  def attack_delay_ms(p_atk_spd), do: trunc(470_000 / p_atk_spd)

  @doc "Restored per 3 s regeneration tick, before anything an effect adds."
  def hp_regen(table_value, con, level, posture),
    do: max(1, table_value * level_mod(level) * bonus(:con, con)) * Map.fetch!(@posture, posture)

  def mp_regen(table_value, men, level, posture),
    do: max(1, table_value * level_mod(level) * bonus(:men, men)) * Map.fetch!(@posture, posture)

  # ---------------------------------------------------------------- combat

  @doc "Where an attacker stands; the game has no geometry, so it is drawn."
  def random_position, do: Math.random_element(@positions)

  @doc "Chance to hit, per mille: 200 to 980 whatever accuracy and evasion say."
  def hit_chance(accuracy, evasion, position) do
    chance = trunc((80 + 2 * (accuracy - evasion)) * 10 * (100 + @hit_bonus[position]) / 100)
    chance |> max(200) |> min(980)
  end

  def hit?(chance), do: chance >= Math.random_int(0, 999)

  def crit?(rate), do: rate > Math.random_int(0, 999)

  @doc "The spread one hit is multiplied by: ±`range`%, which bare hands take from the level."
  def damage_variance(range), do: 1 + Math.random_int(-range, range) / 100
  def unarmed_range(level), do: 5 + trunc(:math.sqrt(level))

  @doc """
  One physical blow. `power` is a skill's, zero for an auto-attack. L2J multiplies the variance in
  twice when randomising auto-attacks, which is a bug and not kept.
  """
  def physical_damage(p_atk, p_def, opts) do
    position = Keyword.get(opts, :position, :front)
    variance = Keyword.get(opts, :variance, 1.0)
    attack = p_atk + Keyword.get(opts, :power, 0)
    damage = 76 * attack * @proximity[position] / p_def
    damage = if Keyword.get(opts, :crit, false), do: 2 * damage, else: damage

    floor_at_one(damage * variance)
  end

  @doc "One spell. A magic critical is ×3 against a monster (×2.5 is between players)."
  def magic_damage(m_atk, m_def, power, opts \\ []) do
    damage = 91 * :math.sqrt(m_atk) / m_def * power
    damage = if Keyword.get(opts, :crit, false), do: damage * 3, else: damage

    floor_at_one(damage * Keyword.get(opts, :variance, 1.0))
  end

  @doc "Percent chance a spell is not resisted, from the level gap alone."
  def magic_success_rate(caster_level, target_level),
    do: 100 - round(:math.pow(1.3, target_level - caster_level))

  @doc """
  Percent chance an effect lands. The target's saving attribute is subtracted outright, and a magic
  one scales with `11 × √M.Atk ÷ M.Def`; `min` and `max` are the skill's own.
  """
  def effect_chance(%{} = e) do
    base = (e.magic_level - e.target_level + 3) * e.level_bonus_rate + e.activate_rate + 30
    base = base - e.target_stat
    magic = if e[:m_atk], do: 11 * :math.sqrt(e.m_atk) / e.m_def, else: 1

    (base * magic) |> max(e.min) |> min(e.max)
  end

  @doc "A monster pays EXP only within ten levels either way; no decay inside that window."
  def exp_share(player_level, monster_level),
    do: if(abs(player_level - monster_level) < 11, do: 1.0, else: 0.0)

  @doc "Bonus EXP for the killing blow's excess, as a share of the monster's HP, up to 25%."
  def overhit_exp(exp, overhit_damage, monster_max_hp),
    do: min(overhit_damage * 100 / monster_max_hp, 25) / 100 * exp

  defp floor_at_one(damage) when damage > 0 and damage < 1, do: 1.0
  defp floor_at_one(damage) when damage < 0, do: 0.0
  defp floor_at_one(damage), do: damage
end
