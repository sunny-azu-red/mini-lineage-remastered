defmodule MiniLineage.Game.Narrative do
  @moduledoc "Port of narrative.service.ts. Each `pick` draws once — reordering shifts every later roll."
  alias MiniLineage.Game.{Constants, Format, Math, Narratives}

  defp pick(templates, data), do: Format.fill_template(Math.random_element(templates), data)

  @doc "Builds the narrative for a resolved fight. `ambushed_after` is the NEW state, rolled by the caller."
  def build_battle(player, result, ambushed_after) do
    weapon = Constants.weapon(player.weapon_id)
    armor = Constants.armor(player.armor_id)
    enemy = Constants.race(Constants.race(player.race_id).enemy_race_id)
    enemies = result.enemies_killed

    ambush_enemies = Math.ambush_enemy_count(enemies, 4)
    ambush_group = Format.pluralize(enemy.label, enemy.plural, ambush_enemies, enemy.emoji)

    data = %{
      "weaponEmoji" => weapon.emoji,
      "weaponName" => weapon.name,
      "armorEmoji" => armor.emoji,
      "armorName" => armor.name,
      "enemyGroup" => Format.pluralize(enemy.label, enemy.plural, enemies, enemy.emoji),
      "enemyEmoji" => enemy.emoji,
      "enemyName" => enemy.label,
      "blocked" => Format.number(result.damage_blocked),
      "xpGained" => Format.number(result.xp_gained),
      "adenaGained" => Format.adena(result.adena_gained),
      "hp" => Format.number(player.health),
      "isSingleEnemy" => enemies == 1,
      "ambushEnemyGroup" => ambush_group,
      "ambushEnemyGroupCap" => Format.capitalize(ambush_group),
      "isSingleAmbush" => ambush_enemies == 1
    }

    # Order is load-bearing: each draws once, so reordering shifts every later roll.
    crit_line = if result.is_critical, do: pick(Narratives.critical(), data), else: nil
    kill_line = pick(Narratives.kill(), data)
    deflection_line = pick(Narratives.deflection(), data)

    outcome_line =
      pick(if(result.is_level_up, do: Narratives.level_up(), else: Narratives.outcome()), data)

    ambush_template = Math.random_element(Narratives.ambush())
    next_move = Math.random_element(Narratives.moves())

    # A fatal fight credits nothing: `resolve_battle_outcome/2` returns at zero health, before the
    # XP, Adena, battle and kill counts. Every line is drawn all the same, so the pools stay in
    # step, then all of them are dropped for the one that is true.
    died = player.dead

    %{
      crit_line: unless(died, do: crit_line),
      kill_line: unless(died, do: kill_line),
      deflection_line: unless(died, do: deflection_line),
      # The reason is stored as it is written, pronouns still open, like every other line here —
      # filling it as "you" now would bake the fighter's own voice into a row strangers read.
      outcome_line: if(died, do: player.death_reason, else: outcome_line),
      ambush_line: if(ambushed_after, do: Format.fill_template(ambush_template, data), else: nil),
      fight_prompt:
        if(ambushed_after, do: if(ambush_enemies == 1, do: "Face your Foe!", else: "Fight them!")),
      # Drawn so the dice land identically, dropped because there is no next move after the last
      # one, and "Sharpen your blade" is not advice a ghost can take.
      next_move: unless(died, do: next_move)
    }
  end

  @doc """
  The warning shown while ambushed and near death. Hashed from the run rather than rolled, because
  the banner re-renders on every tick and a fresh roll would flicker through nine lines as the
  player reads it. Its inputs only move when a fight does, which is what ends the ambush anyway.
  """
  def ambush_low_health(player) do
    pool = Narratives.ambush_low_health()

    Enum.at(pool, rem(:erlang.phash2({player.experience, player.total_ambushes}), length(pool)))
  end

  @doc """
  What an active effect does, in the reader's voice. The values are read off the effect rather than
  its catalog entry, so the regen aura — whose rate is filled in at runtime — describes itself.
  """
  def build_effect(effect, voice) do
    labels = Constants.stat_modifier_labels()

    values =
      Map.new(effect.modifiers, fn mod ->
        config = Map.get(labels, mod.type, %{})

        {to_string(mod.type), Format.modifier(mod.value, Map.get(config, :multiplier?, false))}
      end)

    Format.fill_template(Narratives.effect_blurb(effect.id), Map.merge(values, pronouns(voice)))
  end

  @doc """
  A line told to whoever is reading it. Every battle template is stored with its pronouns still
  open: the numbers and the gear are filled when the fight happens, because they are facts about
  that moment, and who it is being told TO is not known until somebody opens a page. A run's own
  battle screen fills them as "you"; a stranger reading the same row on a record fills them as
  "they", and neither is a second copy of the sentence.
  """
  def voiced(nil, _mine?), do: nil
  def voiced(line, mine?), do: Format.fill_template(line, pronouns(mine?))

  @doc "A death told to whoever is reading it: the fallen player themselves, or anybody else."
  def death_reason(reason, mine?), do: voiced(reason, mine?)

  # ------------------------------------------------------------------ deeds
  #
  # The values are facts about a moment and are filled now; the pronouns are not known until
  # somebody opens the page, so `fill_template/2` leaves them exactly as it leaves a fight's.

  @doc "Who a run set out as. `welcome` still carries its own open pronouns."
  def build_began(race, traits) do
    Format.fill_template(Narratives.began(), %{
      "raceEmoji" => race.emoji,
      "raceLabel" => race.label,
      "welcome" => traits.welcome,
      "build" => traits.build,
      "definition" => traits.definition,
      "age" => traits.age,
      "adena" => Format.adena(traits.adena)
    })
  end

  @doc "What a purchase leaves behind, which is the thing bought."
  def build_purchase(_slot, item), do: named(Narratives.bought_gear(), item)

  def build_meal(item, health),
    do: Narratives.ate() |> named(item) |> Format.fill_template(%{"hp" => Format.number(health)})

  def build_levelled(level), do: Format.fill_template(Narratives.levelled(), %{"level" => level})

  def build_heresy, do: Narratives.heresy()

  @doc "An effect arriving or going. The blurb says what it does; this says that it happened."
  def build_effect_change(template, effect) do
    Format.fill_template(template, %{
      "emoji" => effect.emoji,
      "label" => effect.label,
      "type" => to_string(effect.type)
    })
  end

  defp named(template, item) do
    Format.fill_template(template, %{
      "emoji" => item.emoji,
      "name" => item.name,
      "cost" => Format.adena(item.cost)
    })
  end

  @doc """
  A stored line as its owner's alert: the same sentence, colours and all, told to them. One sentence
  for both, so what the alert says and what the chronicle keeps cannot drift apart.
  """
  def alert(line), do: voiced(line, true)

  defp pronouns(mine?) when is_boolean(mine?), do: mine? |> Narratives.voice() |> pronouns()
  defp pronouns(voice), do: Map.new(voice, fn {part, word} -> {to_string(part), word} end)

  def build_race_traits(race) do
    Format.fill_template(Narratives.race_traits(race.id), %{
      "hp" => Format.number(race.start_health),
      "adena" => Format.adena(race.start_adena),
      "crit" => Format.number(race.crit),
      "regen" => Format.number(race.regen),
      "ambush" => Format.number(race.ambush_chance)
    })
  end
end
