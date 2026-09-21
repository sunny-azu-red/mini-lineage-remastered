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

  @doc "A death told to whoever is reading it: the fallen player themselves, or anybody else."
  def death_reason(nil, _mine?), do: nil

  def death_reason(reason, mine?),
    do: reason |> Narratives.death_template() |> Format.fill_template(pronouns(mine?))

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
