defmodule MiniLineage.Game.Narrative do
  @moduledoc "Each `pick` draws once — reordering shifts every later roll."
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

    %{
      crit_line: crit_line,
      kill_line: kill_line,
      deflection_line: deflection_line,
      outcome_line: outcome_line,
      ambush_line: if(ambushed_after, do: Format.fill_template(ambush_template, data), else: nil),
      fight_prompt:
        if(ambushed_after, do: if(ambush_enemies == 1, do: "Face your Foe!", else: "Fight them!")),
      next_move: next_move
    }
  end

  @doc """
  The warning shown while ambushed and near death. Hashed from the run rather than rolled, because
  the banner re-renders on every tick and a fresh roll would flicker as the player reads it.
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

    values = Map.put(values, "healing", healing(effect.modifiers))

    Format.fill_template(Narratives.effect_blurb(effect.id), Map.merge(values, pronouns(voice)))
  end

  # The 🌿 aura carries whichever of HP and MP is still short, so its sentence names only those.
  defp healing(modifiers) do
    parts =
      for %{type: type, value: value} <- modifiers, type in [:hp_regen, :mp_regen] do
        {class, unit} = if type == :hp_regen, do: {"regen", "HP"}, else: {"mp", "MP"}
        ~s(<span class="#{class}">#{Format.number(value)} #{unit}</span>)
      end

    Enum.join(parts, " and ")
  end

  @doc """
  A stored line told to whoever is reading it: its open pronouns filled as "you" on the run's own
  screen, and as "they" for anybody else.
  """
  def voiced(nil, _mine?), do: nil
  def voiced(line, mine?), do: Format.fill_template(line, pronouns(mine?))

  @doc "A death told to whoever is reading it: the fallen player themselves, or anybody else."
  def death_reason(reason, mine?), do: voiced(reason, mine?)

  # ------------------------------------------------------------------ deeds
  # Values are filled now; the pronouns stay open until render, as a fight's do.

  @doc "Who a run set out as. `welcome` still carries its own open pronouns."
  def build_began(race, traits) do
    Format.fill_template(Narratives.began(), %{
      "raceEmoji" => race.emoji,
      "raceLabel" => race.label,
      "className" => traits.class_name,
      "welcome" => traits.welcome,
      "build" => traits.build,
      "definition" => traits.definition,
      "age" => traits.age,
      "adena" => Format.adena(traits.adena)
    })
  end

  @doc "What a purchase leaves behind, which is the thing bought."
  def build_purchase(item), do: named(Narratives.bought_gear(), item)

  def build_meal(item, health),
    do: Narratives.ate() |> named(item) |> Format.fill_template(%{"hp" => Format.number(health)})

  def build_levelled(level), do: Format.fill_template(Narratives.levelled(), %{"level" => level})

  def build_heresy, do: Narratives.heresy()

  def build_transfer(class) do
    article = if String.first(class.name) in ~w(A E I O U), do: "an", else: "a"

    Format.fill_template(Narratives.transferred(), %{
      "article" => article,
      "className" => class.name
    })
  end

  def build_dye(template, dye, cost),
    do: Format.fill_template(template, %{"name" => dye.name, "cost" => Format.adena(cost)})

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
  A stored line as its owner's alert: the same sentence, colours and all, so the alert and the
  chronicle cannot drift apart.
  """
  def alert(line), do: voiced(line, true)

  defp pronouns(mine?) when is_boolean(mine?), do: mine? |> Narratives.voice() |> pronouns()
  defp pronouns(voice), do: Map.new(voice, fn {part, word} -> {to_string(part), word} end)

  def build_race_traits(race) do
    Format.fill_template(Narratives.race_traits(race.id), %{
      "adena" => Format.adena(race.start_adena),
      "ambush" => Format.number(race.ambush_chance)
    })
  end
end
