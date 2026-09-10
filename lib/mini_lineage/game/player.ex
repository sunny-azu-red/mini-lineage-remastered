defmodule MiniLineage.Game.Player do
  @moduledoc """
  Port of player.service.ts: the stat pipeline, effects, zone auras, purchases and the two tick
  jobs. Every function is pure — it takes a player and returns a new one.
  """
  alias MiniLineage.Game.{Clock, Constants, Format, Math, Narratives, Statistics}

  @zone_aura_ids ~w(resting combat)

  defstruct name: nil,
            race_id: nil,
            health: nil,
            adena: nil,
            experience: nil,
            weapon_id: nil,
            armor_id: nil,
            dead: false,
            ambushed: false,
            coward: false,
            cheated: false,
            death_reason: nil,
            total_battles: 0,
            total_ambushes: 0,
            consecutive_ambushes: 0,
            total_enemies_killed: 0,
            effects: [],
            revision: 0,
            current_screen: nil,
            combat_until: nil,
            last_battle_narrative: nil

  def started?(%__MODULE__{race_id: r, health: h, adena: a}),
    do: r != nil and h != nil and a != nil

  @doc "Clears every game field. The reference preserves session bookkeeping; we hold none."
  def reset(_player), do: %__MODULE__{}

  defp equipment(player) do
    %{
      race: Constants.race(player.race_id || 0),
      weapon: Constants.weapon(player.weapon_id || 0),
      armor: Constants.armor(player.armor_id || 0)
    }
  end

  defp modifiers_of(item), do: Map.get(item, :modifiers, [])

  # ---------------------------------------------------------------- lifecycle

  def initialize(player, race, name) do
    player = %{
      player
      | race_id: race.id,
        name: name,
        health: race.start_health,
        adena: race.start_adena,
        experience: 0,
        weapon_id: 0,
        armor_id: 0,
        total_battles: 0,
        total_ambushes: 0,
        consecutive_ambushes: 0,
        total_enemies_killed: 0,
        effects: []
    }

    player = apply_effect(player, Constants.effect(:newbie_buff))
    player = %{player | health: stats(player).max_health}

    Statistics.increment(:total_players)
    Statistics.increment(:total_adena, player.adena)

    # Draw order is load-bearing only in that it must stay stable: build, then age, then welcome.
    %{min_age: min_age, max_age: max_age, age_thresholds: thresholds, builds: builds} =
      Constants.character()

    build = Math.random_element(builds)
    age = Math.random_int(min_age, max_age)

    definition =
      cond do
        age <= thresholds.youth -> thresholds.labels.youth
        age <= thresholds.adult -> thresholds.labels.adult
        true -> thresholds.labels.elder
      end

    welcome =
      Format.fill_template(Math.random_element(Narratives.welcome()), %{"raceLabel" => race.label})

    flash = %{
      text:
        "You have chosen the #{race.emoji} #{race.label}, #{welcome}\n" <>
          "You are #{build} #{definition} of #{age} seasons, bearing a 🪙 #{Format.adena(player.adena)} Adena tribute.",
      type: :info,
      sound: "start"
    }

    {player, flash}
  end

  def kill(player) do
    player = %{player | health: 0, dead: true, effects: []}
    Statistics.increment(:total_deaths)

    resolve_death_reason(player)
  end

  def commit_suicide(player) do
    # Must be set BEFORE kill/1, whose resolve_death_reason picks the branch on it.
    kill(%{player | coward: true})
  end

  @doc "Fixed once, at time of death, so it is never re-randomized on re-render."
  def resolve_death_reason(%{death_reason: reason} = player) when reason not in [nil, ""],
    do: player

  def resolve_death_reason(%{cheated: true} = player),
    do: %{player | death_reason: "👾 The gods saw your heresy and cast your memory into oblivion."}

  def resolve_death_reason(%{coward: true} = player),
    do: %{player | death_reason: "🤡 You took the cowardly way out."}

  def resolve_death_reason(player),
    do: %{player | death_reason: Math.random_element(Narratives.death())}

  # ------------------------------------------------------------------ effects

  defp to_active(config, expires_at) do
    %{
      id: config.id,
      type: config.type,
      group: Map.get(config, :group),
      emoji: config.emoji,
      label: config.label,
      modifiers: config.modifiers,
      expires_at: expires_at
    }
  end

  @doc "Applies an effect, replacing any active effect sharing its id or its `group` (e.g. food)."
  def apply_effect(player, config) do
    now = Clock.now_ms()
    group = Map.get(config, :group)

    kept =
      Enum.reject(player.effects, fn e ->
        (group != nil and e.group == group) or e.id == config.id or
          (e.expires_at != nil and e.expires_at <= now)
      end)

    expires_at =
      case Map.get(config, :duration_ms) do
        nil -> nil
        ms -> now + ms
      end

    %{player | effects: kept ++ [to_active(config, expires_at)]}
  end

  @doc "Unexpired buffs/debuffs/auras, plus the derived regenerating aura."
  def active_effects(%{dead: true}), do: []

  def active_effects(player) do
    now = Clock.now_ms()
    effects = Enum.filter(player.effects, &(&1.expires_at == nil or &1.expires_at > now))

    if Enum.any?(effects, &(&1.id == "resting")),
      do: effects ++ regen_aura(player, effects),
      else: effects
  end

  # Mirrors stats/1's modifier list by hand rather than calling it, to avoid recursion.
  defp regen_aura(player, effects) do
    %{race: race, weapon: weapon, armor: armor} = equipment(player)

    all = modifiers_of(weapon) ++ modifiers_of(armor) ++ Enum.flat_map(effects, & &1.modifiers)
    sum = fn type -> Enum.reduce(all, 0, &if(&1.type == type, do: &2 + &1.value, else: &2)) end

    effective_max = max(1, race.start_health + sum.(:max_health))
    total_regen = max(0, race.regen + sum.(:regen))

    if player.health < effective_max and total_regen > 0 do
      config = Constants.effect(:regen_aura)
      [to_active(%{config | modifiers: [%{type: :regen, value: total_regen}]}, nil)]
    else
      []
    end
  end

  @doc "Layered pipeline: race base -> equipment stats -> equipment/effect modifiers -> clamps."
  def stats(player) do
    %{race: race, weapon: weapon, armor: armor} = equipment(player)

    base = %{
      attack: weapon.stat,
      defense: armor.stat,
      crit: race.crit,
      max_health: race.start_health,
      regen: race.regen,
      ambush_risk: race.ambush_chance,
      xp_multiplier: 1.0,
      adena_multiplier: 1.0
    }

    # 'regenerating' is derived FROM regen, so folding it back in would double-count.
    modifiers =
      modifiers_of(weapon) ++
        modifiers_of(armor) ++
        (player
         |> active_effects()
         |> Enum.reject(&(&1.id == "regenerating"))
         |> Enum.flat_map(& &1.modifiers))

    stats =
      Enum.reduce(modifiers, base, fn mod, acc ->
        if mod.type in [:xp_multiplier, :adena_multiplier],
          do: Map.update!(acc, mod.type, &(&1 * mod.value)),
          else: Map.update!(acc, mod.type, &(&1 + mod.value))
      end)

    %{
      stats
      | attack: max(stats.attack, 0),
        defense: max(stats.defense, 0),
        crit: stats.crit |> max(0) |> min(100),
        regen: max(stats.regen, 0),
        max_health: max(stats.max_health, 1),
        ambush_risk: stats.ambush_risk |> max(0) |> min(100),
        xp_multiplier: max(stats.xp_multiplier, 0),
        adena_multiplier: max(stats.adena_multiplier, 0)
    }
  end

  # -------------------------------------------------------------- zone auras

  # Actively held in combat: standing in a combat zone, or ambushed anywhere.
  defp held_in_combat?(player) do
    player.ambushed == true or player.current_screen in Constants.zone().combat_zones
  end

  defp resolve_zone_aura(player, before) do
    now = Clock.now_ms()

    cond do
      held_in_combat?(player) ->
        {%{player | combat_until: nil}, to_active(Constants.effect(:combat_aura), nil)}

      true ->
        # An indefinite combat aura means they were standing in a combat zone last sync, so
        # leaving now starts the disengage countdown. Re-entering cancels it (above); leaving
        # again arms a fresh one, anchored to leaving rather than to the last fight.
        player =
          if before != nil and before.id == "combat" and before.expires_at == nil,
            do: %{player | combat_until: now + Constants.zone().combat_linger_ms},
            else: player

        if player.combat_until != nil and player.combat_until > now do
          {player, to_active(Constants.effect(:combat_aura), player.combat_until)}
        else
          player = %{player | combat_until: nil}

          if player.current_screen in Constants.zone().resting_zones,
            do: {player, to_active(Constants.effect(:resting_aura), nil)},
            else: {player, nil}
        end
    end
  end

  @doc "Re-derives the zone aura from `current_screen`. Returns `{player, changed?}`."
  def sync_zone_auras(player) do
    before = Enum.find(player.effects, &(&1.id in @zone_aura_ids))
    player = %{player | effects: Enum.reject(player.effects, &(&1.id in @zone_aura_ids))}

    {player, after_aura} =
      if player.dead, do: {player, nil}, else: resolve_zone_aura(player, before)

    player =
      if after_aura, do: %{player | effects: player.effects ++ [after_aura]}, else: player

    changed =
      field(before, :id) != field(after_aura, :id) or
        field(before, :expires_at) != field(after_aura, :expires_at)

    {player, changed}
  end

  defp field(nil, _key), do: nil
  defp field(map, key), do: Map.get(map, key)

  # ----------------------------------------------------------------- economy

  defp deduct_cost(player, cost) do
    if player.adena < cost,
      do: {player, false},
      else: {%{player | adena: player.adena - cost}, true}
  end

  @doc "Heals up to max HP. Returns `{player, restored}`."
  def restore_health(player, amount) do
    healed = min(stats(player).max_health, player.health + amount)

    {%{player | health: healed}, healed - player.health}
  end

  # --------------------------------------------------------------- tick jobs

  @doc """
  Drops expired effects and clamps health if a max-health buff went away. Driven only by each
  effect's own exact-expiry timer. Returns `{player, changed?}`.
  """
  def process_effect_expiry(%{dead: true} = player), do: {player, false}

  # An unstarted character has no health to clamp, and Elixir orders nil ABOVE every number — so
  # `health > max_health` is true for nil and would invent a health value. JS compares undefined
  # the other way, which is why the reference needs no such guard.
  def process_effect_expiry(%{health: health} = player) when not is_integer(health),
    do: {player, false}

  def process_effect_expiry(player) do
    now = Clock.now_ms()
    remaining = Enum.filter(player.effects, &(&1.expires_at == nil or &1.expires_at > now))
    changed? = length(remaining) != length(player.effects)
    player = if changed?, do: %{player | effects: remaining}, else: player

    max_health = stats(player).max_health

    if player.health > max_health,
      do: {%{player | health: max_health}, true},
      else: {player, changed?}
  end

  @doc """
  Natural HP regeneration, earned by resting. Periodic cadence only. Returns `{player, healed?}`.

  Requires the resting aura outright, rather than merely the absence of combat: a screen in
  neither zone list used to regenerate silently, with no 🌿 aura to show for it.
  """
  def process_regen_tick(%{dead: true} = player), do: {player, false}

  def process_regen_tick(player) do
    if Enum.any?(active_effects(player), &(&1.id == "resting")) do
      stats = stats(player)

      if stats.regen > 0 and player.health < stats.max_health do
        {player, healed} = restore_health(player, stats.regen)

        if healed > 0 do
          Statistics.increment(:total_hp_regen, healed)
          {player, true}
        else
          {player, false}
        end
      else
        {player, false}
      end
    else
      {player, false}
    end
  end

  # --------------------------------------------------------------- purchases

  @equipment %{
    "weapon" => %{slot: :weapon_id, stat: :total_weapons_bought},
    "armor" => %{slot: :armor_id, stat: :total_armors_bought}
  }

  defp catalog_for("weapon"), do: {Constants.weapons(), @equipment["weapon"]}
  defp catalog_for("armor"), do: {Constants.armors(), @equipment["armor"]}
  # Anything else falls through to food, matching the reference's `?? FOODS`.
  defp catalog_for(_type), do: {Constants.foods(), nil}

  @doc "Returns `nil` for an unknown item; `{player, result}` otherwise — including a rejection."
  def purchase(player, type, item_id) when is_integer(item_id) and item_id >= 0 do
    {items, equipment} = catalog_for(type)

    case Enum.at(items, item_id) do
      nil -> nil
      item -> do_purchase(player, item, item_id, equipment)
    end
  end

  def purchase(_player, _type, _item_id), do: nil

  defp do_purchase(player, item, item_id, equipment) do
    if equipment != nil and Map.get(player, equipment.slot) == item_id do
      {player, refusal(item, owned_text(item, equipment.slot))}
    else
      case deduct_cost(player, item.cost) do
        {player, false} ->
          {player,
           refusal(item, "You do not have enough Adena to buy #{item.emoji} #{item.name}!")}

        {player, true} ->
          Statistics.increment(:total_adena_spent, item.cost)
          complete_purchase(player, item, item_id, equipment)
      end
    end
  end

  defp refusal(item, text), do: %{success: false, text: text, item: item}

  defp effect_of(item) do
    case Map.get(item, :effect) do
      nil -> nil
      key -> Constants.effect(key)
    end
  end

  defp owned_text(item, :weapon_id),
    do: "You are already wielding the #{item.emoji} #{item.name}!"

  defp owned_text(item, :armor_id), do: "You are already wearing the #{item.emoji} #{item.name}!"

  defp complete_purchase(player, item, _item_id, nil) do
    effect = effect_of(item)
    player = if effect, do: apply_effect(player, effect), else: player

    {player, healed} = restore_health(player, item.stat)
    Statistics.increment(:total_food_bought)
    Statistics.increment(:total_hp_healed, healed)

    buff =
      if effect,
        do: "\nYou feel invigorated by the #{effect.emoji} #{effect.label} buff!",
        else: ""

    text =
      "You have bought #{item.emoji} #{item.name}.#{buff}\n" <>
        "You feel your strength returning, bringing you to #{Format.number(player.health)} HP."

    {player, %{success: true, text: text, item: item}}
  end

  defp complete_purchase(player, item, item_id, equipment) do
    player = Map.put(player, equipment.slot, item_id)
    Statistics.increment(equipment.stat)

    {player, %{success: true, text: bought_text(item, equipment.slot), item: item}}
  end

  defp bought_text(item, :weapon_id),
    do: "You have bought a Weapon.\nYou are now wielding the swift #{item.emoji} #{item.name}!"

  defp bought_text(item, :armor_id),
    do: "You have bought an Armor.\nYou are now wearing the mighty #{item.emoji} #{item.name}!"

  # ----------------------------------------------------------------- battle

  @doc "Applies a resolved fight. Returns `{player, level_up?}`."
  def resolve_battle_outcome(player, result) do
    player = %{player | health: player.health - result.hp_lost}

    if player.health <= 0 do
      {kill(player), false}
    else
      old_xp = player.experience

      player = %{
        player
        | adena: player.adena + result.adena_gained,
          experience: player.experience + result.xp_gained,
          total_battles: player.total_battles + 1,
          total_enemies_killed: player.total_enemies_killed + result.enemies_killed
      }

      if result.is_critical, do: Statistics.increment(:total_critical_hits)
      Statistics.increment(:total_battles)
      Statistics.increment(:total_enemies_killed, result.enemies_killed)
      Statistics.increment(:total_adena_generated, result.adena_gained)
      Statistics.increment(:total_adena, result.adena_gained)
      Statistics.increment(:total_hp_lost, result.hp_lost)
      Statistics.increment(:total_xp_gained, result.xp_gained)
      Statistics.increment(:total_damage_blocked, result.damage_blocked)

      if Math.level_up?(old_xp, player.experience) do
        {player, healed} = restore_health(player, stats(player).max_health)
        Statistics.increment(:total_levels_gained)
        Statistics.increment(:total_hp_healed, healed)

        {player, true}
      else
        {player, false}
      end
    end
  end
end
