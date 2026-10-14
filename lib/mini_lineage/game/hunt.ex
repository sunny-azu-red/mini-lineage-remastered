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
  # §20: a curse only on a monster above half its HP.
  @curse_above 0.5

  @spells [:magic, :drain, :burn]
  # §20: what a character casts at the monster, each reaching a spell's distance.
  @ranged @spells ++ [:poison, :shackle]

  def round_ms, do: @round_ms
  def max_rounds, do: @max_rounds

  @doc """
  §20: one of the ground's monsters from 3 levels below the character up to its own level, or one
  of the nearest if none is.
  """
  def draw(monsters, level) do
    case Enum.filter(monsters, &(&1.level in (level - 3)..level//1)) do
      [] ->
        gap = fn monster -> abs(monster.level - level) end
        nearest = monsters |> Enum.map(gap) |> Enum.min()
        monsters |> Enum.filter(&(gap.(&1) == nearest)) |> Math.random_element()

      near ->
        Math.random_element(near)
    end
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
  §20: the fight, from the character's stats and bars, the skills it knows (each at its level) and
  the monster (as `foe/1` makes it). The bars may carry `potions` (§26, each `%{name, heals, count}`,
  strongest first) and the `potion_at` share to drink below, and the player's orders, the shares of
  HP to heal below before the pull and in the fight (`heal_pull_at`, `heal_fight_at`; 0 never).
  Returns what is left of both sides, how it went, the auras it raised, which outlast it, the potions
  it `drunk`, the heals cast before the pull (`before`, as `{heals, hp}`), and how long it all took
  in milliseconds (`ms`).
  """
  def fight(stats, %{health: health, mp: mp} = bars, skills, foe) do
    # §23: a weapon skill without its weapon in hand is not used at all; the Learned Skills panel
    # says so, not the log.
    usable = Enum.filter(skills, &Rules.skill_weapon?(&1.name, stats[:weapon]))

    state = %{
      stats: stats,
      health: health,
      mp: mp,
      foe: foe.hp,
      foe_mp: foe.mp,
      cooldowns: %{},
      foe_cooldowns: Map.new(foe.spells, &{&1.name, 0.0}),
      burn: nil,
      poison: nil,
      slowed: 0,
      shackled: 0,
      shackle: 1.0,
      # Auras already up when the fight began, and those raised in it.
      auras: MapSet.new(stats[:auras] || []),
      raised: [],
      potions: Map.get(bars, :potions, []),
      potion_at: Map.get(bars, :potion_at, 0),
      drunk: %{},
      heal_pull_at: Map.get(bars, :heal_pull_at, 0),
      # §20: a Mystic pulls with a spell, a Fighter with its weapon.
      path: Map.get(bars, :path),
      heal_fight_at: Map.get(bars, :heal_fight_at, 0),
      # §20: the heals cast before the pull, newest first, each `{skill, healed}`, and their time.
      mended: [],
      quiet_ms: 0.0,
      toggle: nil,
      toggle_carry: 0.0,
      # §20: how far apart the two stand on the fight's line, set at the pull, and how far its
      # blows reach.
      distance: 0,
      blow_reach:
        if(match?(%{type: "bow"}, stats[:weapon]),
          do: Rules.reach(:bow),
          else: Rules.reach(:blow)
        ),
      # §20: what is left of a spell's cast, during which its caster does nothing else, and the
      # spell, which takes effect as the cast ends (§19).
      busy: 0.0,
      foe_busy: 0.0,
      pending: nil,
      foe_pending: nil,
      # §20: a passive monster stands until the character's first blow, shot or spell reaches it.
      engaged: foe.aggressive?,
      # What happened, newest first, each `{round, event}`: the fight log.
      log: [],
      blows: 0.0,
      foe_blows: 0.0,
      rounds: 0,
      uses: 0,
      critical: false
    }

    state = state |> mend(Enum.filter(usable, &(&1.kind == :heal))) |> settle()
    before = {Enum.reverse(state.mended), state.health}
    state = %{state | distance: opening(state, usable, foe)} |> rounds(usable, foe)

    %{state | log: Enum.reverse(state.log)}
    |> Map.merge(%{before: before, ms: state.rounds * @round_ms + state.quiet_ms})
    |> Map.take(~w(health mp foe rounds uses critical log raised drunk before ms)a)
  end

  defp rounds(%{health: h} = s, _skills, _foe) when h <= 0, do: s
  defp rounds(%{foe: f} = s, _skills, _foe) when f <= 0, do: s
  defp rounds(%{rounds: @max_rounds} = s, _skills, _foe), do: s

  defp rounds(s, skills, foe) do
    s = %{s | rounds: s.rounds + 1} |> burn() |> poison() |> drain_toggle() |> drink()

    # §20: an aggressive monster acts first in the first round, having come at the character.
    s =
      if s.rounds == 1 and foe.aggressive?,
        do: s |> foe_acts(foe) |> character_acts(skills, foe),
        else: s |> character_acts(skills, foe) |> foe_acts(foe)

    # Where both stand when the round is over, so the log's numbers read against something.
    s = note(s, {:standing, s.health, s.foe})

    s = %{
      s
      | cooldowns: Map.new(s.cooldowns, fn {k, v} -> {k, max(v - @round_ms, 0.0)} end),
        busy: max(s.busy - @round_ms, 0.0),
        foe_busy: max(s.foe_busy - @round_ms, 0.0),
        foe_cooldowns: Map.new(s.foe_cooldowns, fn {k, v} -> {k, max(v - @round_ms, 0.0)} end),
        slowed: max(s.slowed - 1, 0),
        shackled: max(s.shackled - 1, 0)
    }

    rounds(s, skills, foe)
  end

  # §26: below its chosen share of HP, one potion a round, the strongest it still carries.
  defp drink(s) do
    potion = Enum.find(s.potions, &(&1.count > 0))

    if potion && s.health * 100 < s.stats.max_hp * s.potion_at do
      healed = min(potion.heals, s.stats.max_hp - s.health)
      left = Enum.map(s.potions, &if(&1 == potion, do: %{&1 | count: &1.count - 1}, else: &1))
      drunk = Map.update(s.drunk, potion.name, 1, &(&1 + 1))

      note(
        %{s | health: s.health + healed, potions: left, drunk: drunk},
        {:potion, potion.name, healed}
      )
    else
      s
    end
  end

  # §19: a burn may take the last HP, a poison never does.
  defp burn(s), do: over_time(s, :burn, s.foe)
  defp poison(s), do: over_time(s, :poison, s.foe - 1)

  defp over_time(s, key, most) do
    case Map.fetch!(s, key) do
      nil ->
        s

      %{rounds: 0} ->
        Map.put(s, key, nil)

      dot ->
        total = dot.carry + dot.per_round
        hit = total |> trunc() |> min(most) |> max(0)
        dot = %{dot | rounds: dot.rounds - 1, carry: total - trunc(total)}
        s = %{Map.put(s, key, dot) | foe: s.foe - hit}
        if hit > 0, do: note(s, {key, hit}), else: s
    end
  end

  # §19: a toggle costs its MP as time goes by, and goes out when the MP does.
  defp drain_toggle(%{toggle: nil} = s), do: s

  defp drain_toggle(%{toggle: toggle} = s) do
    total = s.toggle_carry + toggle.drain * @round_ms / toggle.every
    cost = trunc(total)

    if s.mp >= cost,
      do: %{s | mp: s.mp - cost, toggle_carry: total - cost},
      else: %{s | toggle: nil, stats: Map.update!(s.stats, :p_atk, &(&1 - toggle.power))}
  end

  # §20: before the pull, while below the player's share of HP, the strongest heal it can pay for,
  # waiting out the reuse, until it is not or it cannot pay for one.
  defp mend(s, heals) do
    paid = Enum.filter(heals, &(s.mp >= &1.mp))
    heal = s.busy <= 0 && strongest(s, paid, fn _ -> true end)

    cond do
      s.health * 100 >= s.stats.max_hp * s.heal_pull_at or paid == [] ->
        s

      heal ->
        healed = min(heal_amount(heal.power, s.stats.m_atk), s.stats.max_hp - s.health)
        s = %{spend(s, heal, s.stats.cast_spd) | busy: heal.cast * 333 / s.stats.cast_spd}
        mend(%{s | health: s.health + healed, mended: [{heal.name, healed} | s.mended]}, heals)

      true ->
        mend(wait(s, @round_ms), heals)
    end
  end

  # The last heal's cast is over before the pull; its reuse runs on into the fight.
  defp settle(%{mended: []} = s), do: s
  defp settle(s), do: wait(s, s.busy)

  defp wait(s, ms),
    do: %{
      s
      | cooldowns: Map.new(s.cooldowns, fn {k, v} -> {k, max(v - ms, 0.0)} end),
        busy: max(s.busy - ms, 0.0),
        quiet_ms: s.quiet_ms + ms
    }

  defp character_acts(s, skills, foe) do
    {s, landed?} = land(s, foe)

    cond do
      # A burn may have ended the fight before anybody acts, or the monster's first blow.
      s.foe <= 0 or s.health <= 0 -> s
      s.busy > 0 and landed? -> s
      s.busy > 0 -> note(s, :casting)
      true -> character_turn(s, skills, foe)
    end
  end

  defp foe_acts(s, foe) do
    s = foe_land(s, foe)

    if s.engaged and s.foe > 0 and s.health > 0 and s.foe_busy <= 0,
      do: monster_turn(s, foe),
      else: s
  end

  # §19: a spell takes effect in the round its cast ends.
  defp land(%{pending: nil} = s, _foe), do: {s, false}
  defp land(%{busy: busy} = s, _foe) when busy > @round_ms, do: {s, false}
  defp land(%{pending: skill} = s, foe), do: {take_effect(%{s | pending: nil}, skill, foe), true}

  defp foe_land(%{foe_pending: nil} = s, _foe), do: s
  defp foe_land(%{foe_busy: busy} = s, _foe) when busy > @round_ms, do: s

  defp foe_land(%{foe_pending: spell} = s, foe),
    do: foe_effect(%{s | foe_pending: nil}, foe, spell)

  # §20: what a character does when it is free to: raise its auras, light its toggle, cast its
  # strongest spell, and while its spells rest heal when hurt or curse; otherwise it swings.
  defp character_turn(s, skills, foe) do
    hurt? = s.health * 100 < s.stats.max_hp * s.heal_fight_at
    # A curse is not worth its cast on a monster already half dead.
    fresh? = s.foe > foe.hp * @curse_above

    choice =
      Enum.find(
        skills,
        &(&1.kind == :aura and not MapSet.member?(s.auras, &1.name) and ready?(s, &1))
      ) ||
        Enum.find(
          skills,
          &(&1.kind == :toggle and s.toggle == nil and s.mp >= &1.mp and blows?(s))
        ) ||
        strongest(s, skills, &(&1.kind in @spells and not (&1.kind == :burn and s.burn != nil))) ||
        (hurt? && strongest(s, skills, &(&1.kind == :heal))) ||
        if(fresh?,
          do:
            Enum.find(skills, &(&1.kind == :poison and s.poison == nil and ready?(s, &1))) ||
              Enum.find(skills, &(&1.kind == :shackle and s.shackled == 0 and ready?(s, &1)))
        )

    case choice do
      nil -> out_of_reach(s, skills, foe)
      %{kind: :toggle} = toggle -> light(s, toggle)
      skill -> cast(s, skill, foe)
    end
  end

  defp strongest(s, skills, kind?) do
    skills
    |> Enum.filter(&(kind?.(&1) and ready?(s, &1)))
    |> Enum.max_by(& &1.power, fn -> nil end)
  end

  defp ready?(s, skill), do: Map.get(s.cooldowns, skill.name, 0.0) <= 0 and s.mp >= skill.mp

  defp light(s, toggle) do
    s = %{s | mp: s.mp - toggle.mp, toggle: toggle, toggle_carry: 0.0, uses: s.uses + 1}
    s = %{s | stats: Map.update!(s.stats, :p_atk, &(&1 + toggle.power))}
    note(s, {:toggle, toggle.name})
  end

  # §19: the MP and the reuse at once, the effect as the cast ends; one that ends within the round
  # takes effect in it.
  defp cast(s, skill, foe) do
    s = %{spend(s, skill, s.stats.cast_spd) | busy: skill.cast * 333 / s.stats.cast_spd}

    if s.busy <= @round_ms,
      do: take_effect(s, skill, foe),
      else: note(%{s | pending: skill}, {:begin, skill.name})
  end

  defp take_effect(s, skill, foe) do
    stats = s.stats
    s = if skill.kind in [:heal, :aura], do: s, else: %{s | engaged: true}

    case skill.kind do
      :heal ->
        healed = min(heal_amount(skill.power, stats.m_atk), stats.max_hp - s.health)
        note(%{s | health: s.health + healed}, {:heal, skill.name, healed})

      :aura ->
        s = %{s | auras: MapSet.put(s.auras, skill.name), raised: [skill.name | s.raised]}
        s = %{s | stats: Map.update!(s.stats, skill.stat, &(&1 * skill.times))}
        note(s, {:aura, skill.name})

      :poison ->
        if Formulas.hit?(skill.land) do
          per_round = skill.power * @round_ms / skill.every
          dot = %{per_round: per_round, rounds: rounds_of(skill.lasts), carry: 0.0}
          note(%{s | poison: dot}, {:curse, skill.name, true})
        else
          note(s, {:curse, skill.name, false})
        end

      :shackle ->
        if Formulas.hit?(skill.land) do
          s = %{s | shackled: rounds_of(skill.lasts), shackle: skill.times}
          note(s, {:curse, skill.name, true})
        else
          note(s, {:curse, skill.name, false})
        end

      :burn ->
        per_round = skill.power * @round_ms / 1000
        s = %{s | burn: %{per_round: per_round, rounds: rounds_of(@burn_ms), carry: 0.0}}
        note(s, {:cast, skill.name, 0, false})

      kind ->
        critical? = Formulas.hit?(stats.magic_critical)
        damage = Formulas.magic_damage(stats.m_atk, foe.m_def, skill.power, critical: critical?)
        before = s.foe
        s = s |> wound(round(damage)) |> mark_critical(critical?)
        s = note(s, {:cast, skill.name, before - s.foe, critical?})
        s = if skill[:slow], do: %{s | slowed: rounds_of(@slow_ms)}, else: s

        if kind == :drain,
          do: %{s | health: min(s.health + trunc((before - s.foe) * skill.absorb), stats.max_hp)},
          else: s
    end
  end

  defp rounds_of(ms), do: round(ms / @round_ms)

  # Blows carry their fraction from round to round, as §10 says; the first weapon skill that is
  # ready takes the place of a blow.
  defp swing(s, strikes, foe) do
    {count, carry} = carry_over(s.blows, s.stats.blows_per_round)
    s = %{s | blows: carry}
    # A round with no blow in it is spent getting ready: drawing a bow, or winding up.
    s = if count == 0, do: note(s, :readying), else: %{s | engaged: true}

    Enum.reduce_while(1..count//1, s, fn _, s ->
      s =
        case Enum.find(strikes, &ready?(s, &1)) do
          nil -> blow(s, foe)
          skill -> strike(s, skill, foe)
        end

      if s.foe > 0, do: {:cont, s}, else: {:halt, s}
    end)
  end

  defp carry_over(carry, per_round) do
    total = carry + per_round
    {trunc(total), total - trunc(total)}
  end

  # §19: a physical skill never misses and never crits; a blow lands on its own chance or not at all.
  defp strike(s, skill, foe) do
    stats = s.stats
    s = spend(s, skill, stats.atk_spd)

    if skill.kind == :blow and not Formulas.hit?(blow_chance(stats.dex)) do
      note(s, {:skill, skill.name, 0})
    else
      before = s.foe
      spread = Formulas.damage_spread(stats.spread)
      s = wound(s, round(skill_damage(stats.p_atk, skill.power, foe.p_def, spread)))
      note(s, {:skill, skill.name, before - s.foe})
    end
  end

  @doc "§19: a physical skill's damage, before what it hits takes it."
  def skill_damage(p_atk, power, p_def, spread \\ Formulas.damage_spread()),
    do: max(70 * (p_atk + power) / p_def * spread, 1.0)

  @doc "§19: what a heal mends, its power and √M.Atk, rounded down."
  def heal_amount(power, m_atk), do: trunc(power + :math.sqrt(m_atk))

  @doc "§19: a blow lands 40% × the DEX bonus of the time, at most 80%."
  def blow_chance(dex), do: min(40 * Formulas.bonus(:dex, dex), 80)

  defp blow(s, foe) do
    stats = s.stats

    if Formulas.hit?(Formulas.hit_chance(stats.accuracy, foe.evasion)) do
      critical? = Formulas.hit?(stats.critical)
      spread = Formulas.damage_spread(stats.spread)

      damage =
        Formulas.physical_damage(stats.p_atk, foe.p_def, critical: critical?, spread: spread)

      before = s.foe
      s = s |> wound(round(damage)) |> mark_critical(critical?)
      note(s, {:blow, before - s.foe, critical?})
    else
      note(s, :miss)
    end
  end

  # §20: a monster casts the strongest spell that is ready and reaches, which takes its cast time,
  # or swings, or runs at the character until one of them reaches.
  defp monster_turn(s, foe) do
    ready =
      foe.spells
      |> Enum.filter(
        &(s.foe_cooldowns[&1.name] <= 0 and s.foe_mp >= &1.mp and &1.range >= s.distance)
      )
      |> Enum.max_by(& &1.power, fn -> nil end)

    reach = foe_reach(foe)

    cond do
      ready -> monster_cast(s, foe, ready)
      s.distance <= reach -> monster_swing(s, foe)
      true -> close_in(s, foe, reach)
    end
  end

  # §20: its blows, if they reach; else it waits for a monster that is coming, or runs at one that is
  # not.
  defp out_of_reach(s, skills, foe) do
    cond do
      s.distance <= s.blow_reach ->
        swing(s, Enum.filter(skills, &(&1.kind in [:physical, :blow])), foe)

      s.distance > foe_reach(foe) ->
        note(s, :waiting)

      true ->
        advance(s)
    end
  end

  # §20: a toggle strengthens blows, so a Mystic lights it only once its blows reach.
  defp blows?(s), do: s.path != :mystic or s.distance <= s.blow_reach

  defp foe_reach(foe), do: if(foe.bow?, do: Rules.reach(:bow), else: Rules.reach(:blow))

  # §20: a character whose blows cannot reach a monster that will not come runs at it.
  defp advance(s) do
    step = s.stats.run_spd * @round_ms / 1000
    note(%{s | distance: max(s.distance - step, s.blow_reach)}, :advancing)
  end

  defp close_in(s, foe, reach) do
    speed = foe.run_spd * if(s.slowed > 0, do: @slowed, else: 1)
    note(%{s | distance: max(s.distance - speed * @round_ms / 1000, reach)}, :closing)
  end

  # §20: an aggressive monster comes at the character from where it notices it; otherwise the pull
  # is made from as far as the opening reaches: a Mystic's spell it can pay for, else the weapon.
  defp opening(_s, _skills, %{aggressive?: true}), do: Rules.reach(:notice)

  defp opening(s, skills, _foe) do
    if s.path == :mystic and Enum.any?(skills, &(&1.kind in @ranged and s.mp >= &1.mp)),
      do: Rules.reach(:spell),
      else: s.blow_reach
  end

  defp monster_cast(s, foe, spell) do
    s = %{
      s
      | foe_mp: s.foe_mp - spell.mp,
        foe_busy: spell.cast * 1.0,
        foe_cooldowns: Map.put(s.foe_cooldowns, spell.name, spell.reuse * 1.0)
    }

    if spell.cast <= @round_ms,
      do: foe_effect(s, foe, spell),
      else: note(%{s | foe_pending: spell}, {:foe_begin, spell.name})
  end

  defp foe_effect(s, foe, spell) do
    damage = round(Formulas.magic_damage(foe.m_atk, s.stats.m_def, spell.power))
    lost = min(max(damage, 1), s.health)

    healed =
      if spell.kind == :drain, do: trunc(lost * @monster_absorb), else: 0

    s = note(s, {:foe_cast, spell.name, lost})
    %{s | health: s.health - lost, foe: min(s.foe + healed, foe.hp)}
  end

  defp monster_swing(s, foe) do
    pace =
      if(s.slowed > 0, do: @slowed, else: 1) * if(s.shackled > 0, do: s.shackle, else: 1)

    # §10: a bow draws and reloads, a monster's as a character's.
    per_round =
      if foe.bow?,
        do: Formulas.shots_per_round(foe.atk_spd),
        else: Formulas.blows_per_round(foe.atk_spd)

    {count, carry} = carry_over(s.foe_blows, per_round * pace)
    s = %{s | foe_blows: carry}

    Enum.reduce_while(1..count//1, s, fn _, s ->
      s = monster_blow(s, foe)
      if s.health > 0, do: {:cont, s}, else: {:halt, s}
    end)
  end

  defp monster_blow(s, foe) do
    stats = s.stats

    if Formulas.hit?(Formulas.hit_chance(foe.accuracy, stats.evasion)) do
      critical? = Formulas.hit?(foe.critical)
      spread = Formulas.damage_spread()

      {damage, caught} =
        case block(stats) do
          :perfect ->
            {1, :perfect}

          {:caught, p_def} ->
            {round(
               Formulas.physical_damage(foe.p_atk, p_def, critical: critical?, spread: spread)
             ), :caught}

          p_def ->
            {round(
               Formulas.physical_damage(foe.p_atk, p_def, critical: critical?, spread: spread)
             ), nil}
        end

      lost = min(damage, s.health)
      note(%{s | health: s.health - lost}, {:foe_blow, lost, critical?, caught})
    else
      note(s, :foe_miss)
    end
  end

  @doc "§23: a shield catches at its rate × the DEX bonus; one catch in twenty is perfect."
  def block_chance(rate, dex), do: rate * Formulas.bonus(:dex, dex)

  defp block(%{shield: %{} = shield} = stats) do
    cond do
      not Formulas.hit?(block_chance(shield.shield_rate, stats.dex)) -> stats.p_def
      Formulas.hit?(5) -> :perfect
      true -> {:caught, stats.p_def + shield.shield_def}
    end
  end

  defp block(stats), do: stats.p_def

  # §19: a skill's reuse, scaled by the speed that times it, runs down a round at a time.
  defp spend(s, skill, speed) do
    %{
      s
      | mp: s.mp - skill.mp,
        cooldowns: Map.put(s.cooldowns, skill.name, (skill[:reuse] || 0) * 333 / speed),
        uses: s.uses + 1
    }
  end

  defp wound(s, damage), do: %{s | foe: s.foe - min(max(damage, 1), s.foe)}

  defp note(s, event), do: %{s | log: [{s.rounds, event} | s.log]}

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
