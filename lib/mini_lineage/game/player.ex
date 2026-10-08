defmodule MiniLineage.Game.Player do
  @moduledoc """
  The stat pipeline, effects, zone auras, purchases and the two tick jobs. Every function takes a
  player and returns a new one.
  """
  alias MiniLineage.Game.{
    Classes,
    Clock,
    Constants,
    Dyes,
    Format,
    Formulas,
    Math,
    Narrative,
    Narratives,
    Statistics
  }

  @zone_aura_ids ~w(resting combat)

  defstruct name: nil,
            race_id: nil,
            class_id: nil,
            health: nil,
            mp: nil,
            adena: nil,
            experience: nil,
            weapon_id: nil,
            armor_id: nil,
            dyes: [],
            dead: false,
            ambushed: false,
            # Read, never set: runs that took their own lives before Commit Suicide was removed.
            coward: false,
            cheated: false,
            death_reason: nil,
            total_battles: 0,
            total_ambushes: 0,
            consecutive_ambushes: 0,
            total_enemies_killed: 0,
            effects: [],
            # What the run did this pass, for the process to write and then clear. Declared by the
            # action because no diff can name the blade somebody bought.
            pending_events: [],
            current_screen: nil,
            last_battle_narrative: nil

  def started?(%__MODULE__{race_id: r, health: h, adena: a}),
    do: r != nil and h != nil and a != nil

  defp equipment(player) do
    %{
      race: Constants.race(player.race_id || 0),
      weapon: Constants.weapon(player.weapon_id || 0),
      armor: Constants.armor(player.armor_id || 0)
    }
  end

  defp modifiers_of(item), do: Map.get(item, :modifiers, [])

  # ---------------------------------------------------------------- lifecycle

  def initialize(player, race, archetype, name) do
    class = Classes.starting(race.id, archetype)

    player = %{
      player
      | race_id: race.id,
        class_id: class.id,
        name: name,
        health: 1,
        mp: 0,
        dyes: [],
        adena: race.start_adena,
        experience: 0,
        weapon_id: 0,
        armor_id: 0,
        total_battles: 0,
        total_ambushes: 0,
        consecutive_ambushes: 0,
        total_enemies_killed: 0,
        effects: [],
        # A new character remembers no fight. Left alone it would keep whatever the process was
        # rehydrated with, and the Battleground would open on someone else's last stand.
        last_battle_narrative: nil
    }

    player = apply_effect(player, Constants.effect(:newbie_buff))
    player = restore_fully(player)

    Statistics.increment_for(player, :total_players)
    Statistics.increment_for(player, :total_adena, player.adena)

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

    traits = %{
      class_name: class.name,
      welcome: welcome,
      build: build,
      definition: definition,
      age: age,
      adena: player.adena
    }

    began = Narrative.build_began(race, traits)
    player = log(player, event("start", began))

    flash = %{text: Narrative.alert(began), type: :info, sound: "start"}

    {player, flash}
  end

  def kill(player) do
    player = %{player | health: 0, dead: true, effects: []}
    # Not `increment_for`: the census counts everyone, or the disqualified arrive and never leave.
    Statistics.increment(:total_deaths)

    resolve_death_reason(player)
  end

  @doc "Fixed once, at time of death, so it is never re-randomized on re-render."
  def resolve_death_reason(%{death_reason: reason} = player) when reason not in [nil, ""],
    do: player

  def resolve_death_reason(%{cheated: true} = player),
    do: %{player | death_reason: Narratives.death_cheated()}

  def resolve_death_reason(player),
    do: %{player | death_reason: Math.random_element(Narratives.death())}

  # ------------------------------------------------------------------ effects

  @doc "An effect as a run carries it: its catalog entry, and until when."
  def to_active(config, expires_at) do
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
        (group != nil and e.group == group and e.id != config.id) or
          (e.expires_at != nil and e.expires_at <= now)
      end)

    expires_at =
      case Map.get(config, :duration_ms) do
        nil -> nil
        ms -> now + ms
      end

    active = to_active(config, expires_at)

    # Held in the order they arrived, which is the order the chronicle introduced them and the order
    # they leave in. A refresh logs nothing, so it keeps its place rather than moving to the end.
    effects =
      if Enum.any?(kept, &(&1.id == config.id)),
        do: Enum.map(kept, &if(&1.id == config.id, do: active, else: &1)),
        else: kept ++ [active]

    %{player | effects: effects}
  end

  @doc "Unexpired buffs/debuffs/auras, plus the derived regenerating and ghost auras."
  # The dead carry nothing — `kill/1` empties the list — so the one thing they have is derived, the
  # way the regen aura is. It holds no modifiers, so the stats pipeline folds in nothing.
  def active_effects(%{dead: true}), do: [to_active(Constants.effect(:ghost_aura), nil)]

  def active_effects(player) do
    now = Clock.now_ms()
    effects = Enum.filter(player.effects, &(&1.expires_at == nil or &1.expires_at > now))

    if Enum.any?(effects, &(&1.id == "resting")),
      do: effects ++ regen_aura(player, effects),
      else: effects
  end

  # Takes the effect list rather than reading it back off the player: `active_effects/1` is one of
  # the callers, and asking it for the stats it is still deciding would not terminate.
  defp regen_aura(player, effects) do
    stats = stats_from(player, effects)

    healing =
      [{:hp_regen, player.health, stats.max_hp}, {:mp_regen, player.mp || 0, stats.max_mp}]
      |> Enum.filter(fn {key, now, max} -> now < max and Math.js_round(stats[key]) > 0 end)
      |> Enum.map(fn {key, _now, _max} -> %{type: key, value: Math.js_round(stats[key])} end)

    if healing == [],
      do: [],
      else: [to_active(%{Constants.effect(:regen_aura) | modifiers: healing}, nil)]
  end

  @doc """
  Interlude's order: the class's attributes and dyes, the naked or equipped bases, the attribute and
  level multipliers, then what effects multiply, then what they add, then the caps.
  """
  def stats(player) do
    # 'regenerating' is derived FROM regen, so folding it back in would double-count.
    effects = Enum.reject(active_effects(player), &(&1.id == "regenerating"))

    stats_from(player, effects)
  end

  @attributes ~w(str con dex int wit men)a

  defp stats_from(player, effects) do
    %{race: race, weapon: weapon, armor: armor} = equipment(player)
    class_id = class_id(player)
    level = Math.level_for_xp(player.experience || 0)
    bases = Classes.bases(class_id)

    modifiers =
      modifiers_of(weapon) ++ modifiers_of(armor) ++ Enum.flat_map(effects, & &1.modifiers)

    a = attributes(player, class_id)

    # Resting is the game's sitting down: it is the only posture anything regenerates in.
    derived = %{
      p_atk: Formulas.p_atk(weapon.stat, a.str, level),
      m_atk: Formulas.m_atk(bases.m_atk, a.int, level),
      p_def: Formulas.p_def(bases.p_def + armor.stat, level),
      m_def: Formulas.m_def(bases.m_def, a.men, level),
      accuracy: Formulas.accuracy(a.dex, level),
      evasion: Formulas.evasion(a.dex, level),
      crit_rate: Formulas.crit_rate(bases.crit, a.dex),
      m_crit_rate: Formulas.m_crit_rate(bases.m_crit, a.wit),
      p_atk_spd: Formulas.p_atk_spd(bases.p_atk_spd, a.dex),
      m_atk_spd: Formulas.m_atk_spd(bases.m_atk_spd, a.wit),
      max_hp: Formulas.max_hp(Classes.hp(class_id, level), a.con),
      max_mp: Formulas.max_mp(Classes.mp(class_id, level), a.men),
      hp_regen: Formulas.hp_regen(Classes.hp_regen(level), a.con, level, :sitting),
      mp_regen: Formulas.mp_regen(Classes.mp_regen(level), a.men, level, :sitting),
      ambush_risk: race.ambush_chance,
      xp_multiplier: 1.0,
      adena_multiplier: 1.0
    }

    {muls, adds} = Enum.split_with(modifiers, &(Map.get(&1, :op) == :mul))

    stats =
      Enum.reduce(adds, Enum.reduce(muls, derived, &apply_modifier/2), &apply_modifier/2)

    stats
    |> Map.merge(a)
    |> clamp()
  end

  defp apply_modifier(%{op: :mul} = mod, acc), do: Map.update!(acc, mod.type, &(&1 * mod.value))
  defp apply_modifier(mod, acc), do: Map.update!(acc, mod.type, &(&1 + mod.value))

  defp clamp(stats) do
    caps = Formulas.caps()

    floors =
      Map.new(
        ~w(p_atk m_atk p_def m_def hp_regen mp_regen xp_multiplier adena_multiplier)a,
        fn key ->
          {key, max(stats[key], 0)}
        end
      )

    Map.merge(stats, floors)
    |> Map.merge(%{
      crit_rate: stats.crit_rate |> max(0) |> min(caps.crit_rate),
      m_crit_rate: stats.m_crit_rate |> max(0) |> min(caps.m_crit_rate),
      evasion: min(stats.evasion, caps.evasion),
      p_atk_spd: stats.p_atk_spd |> max(1) |> min(caps.p_atk_spd),
      m_atk_spd: stats.m_atk_spd |> max(1) |> min(caps.m_atk_spd),
      max_hp: max(trunc(stats.max_hp), 1),
      max_mp: max(trunc(stats.max_mp), 1),
      ambush_risk: stats.ambush_risk |> max(0) |> min(100)
    })
  end

  @doc "The class a run is, or its race's Fighter for one stored before classes existed."
  def class_id(%{class_id: id}) when is_integer(id), do: id
  def class_id(player), do: Classes.starting(player.race_id || 0, :fighter).id

  @doc "The class's six attributes, then every dye's, each dye bonus capped at +5 as Interlude caps it."
  def attributes(player, class_id \\ nil) do
    base = Classes.attributes(class_id || class_id(player))
    dyes = Enum.map(player.dyes || [], &Dyes.get/1)

    Map.new(@attributes, fn attr ->
      gained = Enum.reduce(dyes, 0, fn dye, total -> total + min(dye[attr], 5 - total) end)
      {attr, base[attr] + gained}
    end)
  end

  # -------------------------------------------------------------- zone auras

  # Actively held in combat: standing in a combat zone, or ambushed anywhere.
  defp held_in_combat?(player) do
    player.ambushed == true or player.current_screen in Constants.zone().combat_zones
  end

  # The disengage countdown lives on the combat aura itself, as its expiry: there is no second copy
  # of it on the player to keep in step.
  defp resolve_zone_aura(player, before) do
    cond do
      held_in_combat?(player) ->
        to_active(Constants.effect(:combat_aura), nil)

      until = lingering_until(before) ->
        to_active(Constants.effect(:combat_aura), until)

      player.current_screen in Constants.zone().resting_zones ->
        to_active(Constants.effect(:resting_aura), nil)

      true ->
        nil
    end
  end

  # Indefinite means they stood in a combat zone at the last sync, so leaving now starts the
  # countdown, anchored to leaving rather than to the last fight. A countdown still running holds.
  defp lingering_until(%{id: "combat", expires_at: nil}),
    do: Clock.now_ms() + Constants.zone().combat_linger_ms

  defp lingering_until(%{id: "combat", expires_at: until}),
    do: if(until > Clock.now_ms(), do: until)

  defp lingering_until(_before), do: nil

  @doc "Re-derives the zone aura from `current_screen`. Returns `{player, changed?}`."
  def sync_zone_auras(player) do
    before = Enum.find(player.effects, &(&1.id in @zone_aura_ids))
    player = %{player | effects: Enum.reject(player.effects, &(&1.id in @zone_aura_ids))}

    after_aura = if player.dead, do: nil, else: resolve_zone_aura(player, before)

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
    healed = min(stats(player).max_hp, player.health + amount)

    {%{player | health: healed}, healed - player.health}
  end

  @doc "Restores MP up to its maximum. Returns `{player, restored}`."
  def restore_mp(player, amount) do
    current = player.mp || 0
    restored = min(stats(player).max_mp, current + amount)

    {%{player | mp: restored}, restored - current}
  end

  @doc "Both bars to the top, as a new character and a level reached have them."
  def restore_fully(player) do
    stats = stats(player)
    %{player | health: stats.max_hp, mp: stats.max_mp}
  end

  # --------------------------------------------------------------- tick jobs

  @doc """
  Drops expired effects and clamps HP and MP if a maximum went away with one. Every pass of the
  character's process sweeps; an effect's own timer only makes one happen on time. Returns
  `{player, changed?}`.
  """
  def process_effect_expiry(%{dead: true} = player), do: {player, false}

  # Elixir orders nil ABOVE every number, so `health > max_health` would invent a health value for
  # an unstarted character.
  def process_effect_expiry(%{health: health} = player) when not is_integer(health),
    do: {player, false}

  def process_effect_expiry(player) do
    now = Clock.now_ms()
    remaining = Enum.filter(player.effects, &(&1.expires_at == nil or &1.expires_at > now))
    changed? = length(remaining) != length(player.effects)
    player = if changed?, do: %{player | effects: remaining}, else: player

    clamped = clamp_bars(player)

    {clamped, changed? or clamped != player}
  end

  # A maximum that fell takes the bar down with it; one that rose leaves it where it was.
  defp clamp_bars(player) do
    stats = stats(player)
    %{player | health: min(player.health, stats.max_hp), mp: min(player.mp || 0, stats.max_mp)}
  end

  @doc """
  Natural HP and MP regeneration, earned by resting, one 3 s tick of it. Returns `{player, healed?}`.
  Driven by the 🌿 aura rather than a second copy of its conditions, so the two cannot come apart.
  """
  def process_regen_tick(%{dead: true} = player), do: {player, false}

  def process_regen_tick(player) do
    case Enum.find(active_effects(player), &(&1.id == "regenerating")) do
      nil ->
        {player, false}

      %{modifiers: rates} ->
        player =
          Enum.reduce(rates, player, fn
            %{type: :hp_regen, value: rate}, player ->
              {player, healed} = restore_health(player, rate)
              Statistics.increment_for(player, :total_hp_regen, healed)
              player

            %{type: :mp_regen, value: rate}, player ->
              player |> restore_mp(rate) |> elem(0)
          end)

        {player, true}
    end
  end

  # --------------------------------------------------------------- purchases

  defp catalog_for("weapon"),
    do: {Constants.weapons(), %{slot: :weapon_id, stat: :total_weapons_bought}}

  defp catalog_for("armor"),
    do: {Constants.armors(), %{slot: :armor_id, stat: :total_armors_bought}}

  defp catalog_for("food"), do: {Constants.foods(), nil}

  @doc """
  `{player, result}`, a refusal included. The item is one `Actions` has already validated, which is
  the boundary: an id that is not on sale never reaches here.
  """
  def purchase(player, type, item_id) do
    {items, equipment} = catalog_for(type)
    do_purchase(player, Enum.at(items, item_id), item_id, equipment)
  end

  defp do_purchase(player, item, item_id, equipment) do
    if equipment != nil and Map.get(player, equipment.slot) == item_id do
      {player, refusal(owned_text(item, equipment.slot))}
    else
      case deduct_cost(player, item.cost) do
        {player, false} ->
          {player,
           refusal(
             ~s(You do not have enough <span class="adena">🪙 Adena</span> to buy #{named(item)}!)
           )}

        {player, true} ->
          Statistics.increment_for(player, :total_adena_spent, item.cost)
          complete_purchase(player, item, item_id, equipment)
      end
    end
  end

  defp refusal(text), do: %{success: false, text: text}

  defp effect_of(item) do
    case Map.get(item, :effect) do
      nil -> nil
      key -> Constants.effect(key)
    end
  end

  defp owned_text(item, :weapon_id),
    do: "You are already wielding the #{named(item)}!"

  defp owned_text(item, :armor_id), do: "You are already wearing the #{named(item)}!"

  # The same markup a purchase's sentence gives an item, so a refusal is styled like one.
  defp named(item), do: ~s(#{item.emoji} <span class="item">#{item.name}</span>)

  defp complete_purchase(player, item, _item_id, nil) do
    effect = effect_of(item)
    player = if effect, do: apply_effect(player, effect), else: player

    # A share of the bar, as the battle bridge's losses are: both were tuned against 100 HP.
    {player, healed} = restore_health(player, round(item.stat * stats(player).max_hp / 100))
    Statistics.increment_for(player, :total_food_bought)
    Statistics.increment_for(player, :total_hp_healed, healed)

    bought = Narrative.build_meal(item, player.health)
    player = log(player, event("purchase", bought))

    # The buff has a row of its own in the chronicle; the alert says it in that row's words.
    settled =
      if effect,
        do:
          " " <>
            Narrative.alert(Narrative.build_effect_change(Narratives.effect_gained(), effect)),
        else: ""

    {player, %{success: true, text: Narrative.alert(bought) <> settled}}
  end

  defp complete_purchase(player, item, item_id, equipment) do
    player = Map.put(player, equipment.slot, item_id)
    Statistics.increment_for(player, equipment.stat)
    bought = Narrative.build_purchase(item)
    player = log(player, event("purchase", bought))

    {player, %{success: true, text: Narrative.alert(bought)}}
  end

  # --------------------------------------------------------- classes and dyes

  @doc "Becomes `class`, whose HP and MP tables take over from the next level. Returns `{player, line}`."
  def transfer(player, class) do
    line = Narrative.build_transfer(class)
    player = %{player | class_id: class.id} |> clamp_bars() |> log(event("class_change", line))

    {player, line}
  end

  @doc "Pays for a dye and draws it into the next free slot. `{player, result}`, a refusal included."
  def draw_dye(player, dye) do
    cost = Dyes.cost(dye)

    case deduct_cost(player, cost) do
      {player, false} ->
        {player,
         refusal(
           ~s(You do not have enough <span class="adena">🪙 Adena</span> to have the <span class="item">#{dye.name}</span> drawn!)
         )}

      {player, true} ->
        Statistics.increment_for(player, :total_adena_spent, cost)
        line = Narrative.build_dye(Narratives.dye_drawn(), dye, cost)

        player =
          %{player | dyes: player.dyes ++ [dye.id]} |> clamp_bars() |> log(event("dye", line))

        {player, %{success: true, text: Narrative.alert(line)}}
    end
  end

  @doc "Pays the Symbol Maker to wash away the dye in slot `index`. `{player, result}`."
  def remove_dye(player, index) do
    dye = Dyes.get(Enum.at(player.dyes, index))

    case deduct_cost(player, dye.cancel_fee) do
      {player, false} ->
        {player,
         refusal(
           ~s(You do not have enough <span class="adena">🪙 Adena</span> to have the <span class="item">#{dye.name}</span> washed away!)
         )}

      {player, true} ->
        Statistics.increment_for(player, :total_adena_spent, dye.cancel_fee)
        line = Narrative.build_dye(Narratives.dye_removed(), dye, dye.cancel_fee)

        player =
          %{player | dyes: List.delete_at(player.dyes, index)}
          |> clamp_bars()
          |> log(event("dye", line))

        {player, %{success: true, text: Narrative.alert(line)}}
    end
  end

  # ------------------------------------------------------------------- log

  @doc """
  Notes something the run did, for the process to write and then clear. Appended, because they
  are read in the order they happened.
  """
  def log(player, event), do: %{player | pending_events: player.pending_events ++ [event]}

  @doc "A deed, stamped when it happened rather than when the row reaches the database."
  def event(kind, line), do: %{kind: kind, line: line, at: Clock.now()}

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

      if result.is_critical, do: Statistics.increment_for(player, :total_critical_hits)
      Statistics.increment_for(player, :total_battles)
      Statistics.increment_for(player, :total_enemies_killed, result.enemies_killed)
      Statistics.increment_for(player, :total_adena_generated, result.adena_gained)
      Statistics.increment_for(player, :total_adena, result.adena_gained)
      Statistics.increment_for(player, :total_hp_lost, result.hp_lost)
      Statistics.increment_for(player, :total_xp_gained, result.xp_gained)
      Statistics.increment_for(player, :total_damage_blocked, result.damage_blocked)

      if Math.level_up?(old_xp, player.experience) do
        before = player.health
        player = restore_fully(player)
        healed = player.health - before
        Statistics.increment_for(player, :total_levels_gained)
        Statistics.increment_for(player, :total_hp_healed, healed)

        {player, true}
      else
        {player, false}
      end
    end
  end
end
