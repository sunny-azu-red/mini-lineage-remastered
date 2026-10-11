defmodule MiniLineage.Game.Hunt do
  @moduledoc """
  Rules §20, the one-click hunt: a monster drawn near the character's level, fought round by round
  to the end, and what it pays. Pure but for the dice, which draw through `Math` so a test can pin
  them; nothing here touches a process or the database.
  """
  alias MiniLineage.Game.{Formulas, Math, Rules}

  # §20: one blow at 300 Atk. Spd., Lineage II's 500,000 ÷ Atk. Spd. milliseconds.
  @round_ms 500_000 / 300
  @max_rounds 1_000
  # §19: a burn lasts 15 seconds and Ice Bolt's slow 120, counted in rounds.
  @burn_ms 15_000
  @slow_ms 120_000
  @slowed 0.7
  # §19: a monster's drain heals it this share of what the character lost.
  @monster_absorb 0.2

  def round_ms, do: @round_ms
  def max_rounds, do: @max_rounds

  @doc "§20: one of the ground's monsters within 2 levels of the character, or one of the nearest."
  def draw(monsters, level) do
    gap = fn monster -> abs(monster.level - level) end
    nearest = monsters |> Enum.map(gap) |> Enum.min()
    reach = max(nearest, 2)

    monsters |> Enum.filter(&(gap.(&1) <= reach)) |> Math.random_element()
  end

  @doc "§18: a monster's Accuracy, Evasion and Critical, worked as a character's are."
  def foe(monster) do
    accuracy = Formulas.accuracy(monster.dex, monster.level)

    Map.merge(monster, %{
      accuracy: accuracy,
      evasion: accuracy,
      critical: Formulas.critical(monster.dex),
      spells: Enum.map(monster.spells, &Rules.monster_spell/1)
    })
  end

  @doc """
  §20: the fight, from the character's stats and bars, its first skill and the monster (as `foe/1`
  makes it). Returns what is left of both sides and how it went.
  """
  def fight(stats, %{health: health, mp: mp}, skill, foe) do
    # §23: a skill without its weapon in hand is not used at all.
    skill = if Rules.skill_weapon?(skill.name, stats[:weapon]), do: skill, else: nil

    state = %{
      health: health,
      mp: mp,
      foe: foe.hp,
      foe_mp: foe.mp,
      cooldown: 0.0,
      foe_cooldowns: Map.new(foe.spells, &{&1.name, 0.0}),
      burn: nil,
      slowed: 0,
      blows: 0.0,
      foe_blows: 0.0,
      rounds: 0,
      uses: 0,
      critical: false
    }

    state
    |> rounds(stats, skill, foe)
    |> Map.take(~w(health mp foe rounds uses critical)a)
  end

  defp rounds(%{health: h} = s, _stats, _skill, _foe) when h <= 0, do: s
  defp rounds(%{foe: f} = s, _stats, _skill, _foe) when f <= 0, do: s
  defp rounds(%{rounds: @max_rounds} = s, _stats, _skill, _foe), do: s

  defp rounds(s, stats, skill, foe) do
    s = %{s | rounds: s.rounds + 1} |> burn() |> character_turn(stats, skill, foe)
    s = if s.foe > 0, do: monster_turn(s, stats, foe), else: s

    s = %{
      s
      | cooldown: max(s.cooldown - @round_ms, 0.0),
        foe_cooldowns: Map.new(s.foe_cooldowns, fn {k, v} -> {k, max(v - @round_ms, 0.0)} end),
        slowed: max(s.slowed - 1, 0)
    }

    rounds(s, stats, skill, foe)
  end

  # §19: a burn never takes the last HP.
  defp burn(%{burn: nil} = s), do: s
  defp burn(%{burn: %{rounds: 0}} = s), do: %{s | burn: nil}

  defp burn(%{burn: burn} = s) do
    total = burn.carry + burn.per_round
    hit = total |> trunc() |> min(s.foe - 1) |> max(0)
    %{s | foe: s.foe - hit, burn: %{burn | rounds: burn.rounds - 1, carry: total - trunc(total)}}
  end

  defp character_turn(s, stats, nil, foe), do: swing(s, stats, nil, foe)

  defp character_turn(s, stats, %{kind: kind} = skill, foe)
       when kind in [:magic, :drain, :burn] do
    if ready?(s, skill), do: cast(s, stats, skill, foe), else: swing(s, stats, nil, foe)
  end

  defp character_turn(s, stats, skill, foe), do: swing(s, stats, skill, foe)

  defp ready?(s, skill), do: s.cooldown <= 0 and s.mp >= skill.mp

  defp cast(s, stats, skill, foe) do
    s = spend(s, skill, stats.cast_spd)

    case skill.kind do
      :burn ->
        per_round = skill.power * @round_ms / 1000
        %{s | burn: %{per_round: per_round, rounds: rounds_of(@burn_ms), carry: 0.0}}

      kind ->
        critical? = Formulas.hit?(stats.magic_critical)
        damage = Formulas.magic_damage(stats.m_atk, foe.m_def, skill.power, critical: critical?)
        before = s.foe
        s = s |> wound(round(damage)) |> mark_critical(critical?)
        s = if skill[:slow], do: %{s | slowed: rounds_of(@slow_ms)}, else: s

        if kind == :drain,
          do: %{s | health: min(s.health + trunc((before - s.foe) * skill.absorb), stats.max_hp)},
          else: s
    end
  end

  defp rounds_of(ms), do: round(ms / @round_ms)

  # Blows carry their fraction from round to round, as §10 says.
  defp swing(s, stats, skill, foe) do
    {count, carry} = carry_over(s.blows, stats.blows_per_round)
    s = %{s | blows: carry}

    Enum.reduce_while(1..count//1, s, fn _, s ->
      s =
        if skill && ready?(s, skill), do: strike(s, stats, skill, foe), else: blow(s, stats, foe)

      if s.foe > 0, do: {:cont, s}, else: {:halt, s}
    end)
  end

  defp carry_over(carry, per_round) do
    total = carry + per_round
    {trunc(total), total - trunc(total)}
  end

  # §19: a physical skill never misses and never crits; a blow lands on its own chance or not at all.
  defp strike(s, stats, skill, foe) do
    s = spend(s, skill, stats.atk_spd)

    if skill.kind == :blow and not Formulas.hit?(blow_chance(stats.dex)) do
      s
    else
      wound(s, round(skill_damage(stats.p_atk, skill.power, foe.p_def)))
    end
  end

  @doc "§19: a physical skill's damage, before what it hits takes it."
  def skill_damage(p_atk, power, p_def, spread \\ Formulas.damage_spread()),
    do: max(70 * (p_atk + power) / p_def * spread, 1.0)

  @doc "§19: a blow lands 40% × the DEX bonus of the time, at most 80%."
  def blow_chance(dex), do: min(40 * Formulas.bonus(:dex, dex), 80)

  defp blow(s, stats, foe) do
    if Formulas.hit?(Formulas.hit_chance(stats.accuracy, foe.evasion)) do
      critical? = Formulas.hit?(stats.critical)
      spread = Formulas.damage_spread()

      damage =
        Formulas.physical_damage(stats.p_atk, foe.p_def, critical: critical?, spread: spread)

      s |> wound(round(damage)) |> mark_critical(critical?)
    else
      s
    end
  end

  # §20: a monster casts the strongest spell that is ready, which takes the round, or swings.
  defp monster_turn(s, stats, foe) do
    ready =
      foe.spells
      |> Enum.filter(&(s.foe_cooldowns[&1.name] <= 0 and s.foe_mp >= &1.mp))
      |> Enum.max_by(& &1.power, fn -> nil end)

    if ready, do: monster_cast(s, stats, foe, ready), else: monster_swing(s, stats, foe)
  end

  defp monster_cast(s, stats, foe, spell) do
    damage = round(Formulas.magic_damage(foe.m_atk, stats.m_def, spell.power))
    lost = min(max(damage, 1), s.health)

    healed =
      if spell.kind == :drain, do: trunc(lost * @monster_absorb), else: 0

    %{
      s
      | health: s.health - lost,
        foe: min(s.foe + healed, foe.hp),
        foe_mp: s.foe_mp - spell.mp,
        foe_cooldowns: Map.put(s.foe_cooldowns, spell.name, spell.reuse * 1.0)
    }
  end

  defp monster_swing(s, stats, foe) do
    pace = if s.slowed > 0, do: @slowed, else: 1
    {count, carry} = carry_over(s.foe_blows, Formulas.blows_per_round(foe.atk_spd) * pace)
    s = %{s | foe_blows: carry}

    Enum.reduce_while(1..count//1, s, fn _, s ->
      s = monster_blow(s, stats, foe)
      if s.health > 0, do: {:cont, s}, else: {:halt, s}
    end)
  end

  defp monster_blow(s, stats, foe) do
    if Formulas.hit?(Formulas.hit_chance(foe.accuracy, stats.evasion)) do
      critical? = Formulas.hit?(foe.critical)
      spread = Formulas.damage_spread()

      damage =
        case block(stats) do
          :perfect ->
            1

          p_def ->
            round(Formulas.physical_damage(foe.p_atk, p_def, critical: critical?, spread: spread))
        end

      %{s | health: max(s.health - damage, 0)}
    else
      s
    end
  end

  @doc "§23: a shield catches at its rate × the DEX bonus; one catch in twenty is perfect."
  def block_chance(rate, dex), do: rate * Formulas.bonus(:dex, dex)

  defp block(%{shield: %{} = shield} = stats) do
    cond do
      not Formulas.hit?(block_chance(shield.shield_rate, stats.dex)) -> stats.p_def
      Formulas.hit?(5) -> :perfect
      true -> stats.p_def + shield.shield_def
    end
  end

  defp block(stats), do: stats.p_def

  # §19: a skill's reuse, scaled by the speed that times it, runs down a round at a time.
  defp spend(s, skill, speed),
    do: %{s | mp: s.mp - skill.mp, cooldown: skill.reuse * 333 / speed, uses: s.uses + 1}

  defp wound(s, damage), do: %{s | foe: s.foe - min(max(damage, 1), s.foe)}

  defp mark_critical(s, true), do: %{s | critical: true}
  defp mark_critical(s, false), do: s

  @doc """
  §20 and §22: EXP or SP at the server's rate, shrinking by 5/6 a level once the character is more
  than 5 above the monster.
  """
  def reward(kind, amount, level, monster_level) do
    gap = level - monster_level
    penalty = if gap > 5, do: :math.pow(5 / 6, gap - 5), else: 1
    trunc(amount * Rules.rate(kind) * penalty)
  end

  @doc "§18 and §22: the Adena a slain monster carries, if it carries any, at the server's rate."
  def adena(monster) do
    if Formulas.hit?(monster.adena_chance),
      do: Math.random_int(monster.adena_min, monster.adena_max) * Rules.rate(:adena),
      else: 0
  end
end
