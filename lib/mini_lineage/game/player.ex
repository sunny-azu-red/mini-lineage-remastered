defmodule MiniLineage.Game.Player do
  @moduledoc """
  A character as the base layer (`docs/rules.md`) makes one, and what time does to it. Every
  function takes a player and returns a new one; nothing here touches a process or the database.
  """
  alias MiniLineage.Game.{Clock, Constants, Formulas, Math, Narrative, Narratives, Rules}

  @elf 2
  @dark_elf 3

  defstruct name: nil,
            race_id: nil,
            path: nil,
            health: nil,
            mp: nil,
            adena: nil,
            experience: nil,
            sp: nil,
            location: nil,
            # Rules §21: a run that died is over, and keeps what killed it.
            dead: false,
            killer: nil,
            # Rules §23: what it carries, each `%{id, name, equipped}`. Stored in its own table.
            items: [],
            # Rules §25: each skill it knows, at the level it knows it.
            skills: %{}

  def started?(%__MODULE__{race_id: race_id, path: path}), do: race_id != nil and path != nil

  # ---------------------------------------------------------------- creation

  @doc """
  Rules §1: a race, a path, level 1, full bars and no Adena, standing in the race's village. Returns
  `{player, flash}`.
  """
  def initialize(player, race, path, name) do
    player =
      restore_fully(%{
        player
        | name: name,
          race_id: race.id,
          path: path,
          experience: 0,
          sp: 0,
          adena: 0,
          location: Rules.hometown(race.id),
          items: kit(race.id, path),
          skills: %{Rules.first_skill(race.id, path).name => 1}
      })

    # Draw order is load-bearing only in that it must stay stable: build, then age, then welcome.
    %{min_age: min_age, max_age: max_age, age_thresholds: thresholds, builds: builds} =
      Constants.character()

    build = Math.random_element(builds)
    age = Math.random_int(min_age, max_age)

    definition =
      cond do
        age <= thresholds.youth -> "youth"
        age <= thresholds.adult -> "adult"
        true -> "elder"
      end

    welcome = Math.random_element(Narratives.welcome())

    began =
      Narrative.build_began(race, %{
        class_name: Rules.set(race.id, path).name,
        welcome: welcome,
        build: build,
        definition: definition,
        age: age
      })

    {player, %{text: Narrative.alert(began), type: :info, sound: "start"}}
  end

  # ------------------------------------------------------------------- stats

  def level(player), do: Math.level_for_xp(player.experience || 0)

  @doc """
  Every stat of rules §3 to §11, worked from the set the run started as and its level, then changed
  by whatever `conditions/1` puts on it.
  """
  def stats(player), do: stats(player, conditions(player))

  # Under conditions read once, so one call cannot straddle dusk. The masteries (§25) come before
  # the conditions, as a character's own before what the hour or the place puts on it.
  defp stats(player, conditions) do
    stats = player |> base_stats() |> masteries(player)

    Enum.reduce(conditions, stats, fn aura, stats ->
      Enum.reduce(aura.modifiers, stats, &modify/2)
    end)
  end

  # Rules §25: each mastery known, multipliers before additions, each only in the armour it needs.
  defp masteries(stats, player) do
    chest = Enum.find(worn(player), &(&1.slot == :chest))
    armour = chest && chest.type

    effects =
      for {name, level} <- player.skills || %{},
          Rules.mastery?(name),
          effect <- Rules.mastery(name, player.path, level),
          wears?(effect, armour),
          do: effect

    {muls, adds} = Enum.split_with(effects, fn {_, change} -> elem(change, 0) == :mul end)

    Enum.reduce(muls ++ adds, stats, fn {stat, change}, acc ->
      modify({stat, {elem(change, 0), elem(change, 1)}}, acc)
    end)
  end

  defp wears?({_stat, {_op, _value, needs}}, armour), do: armour == needs
  defp wears?(_effect, _armour), do: true

  defp modify({stat, {:add, value}}, stats), do: Map.update!(stats, stat, &(&1 + value))
  defp modify({stat, {:mul, value}}, stats), do: Map.update!(stats, stat, &(&1 * value))

  defp base_stats(player) do
    set = Rules.set(player.race_id, player.path)
    path = Rules.path(player.path)
    a = set.attributes
    level = level(player)
    worn = worn(player)
    weapon = Enum.find(worn, &(&1.kind == :weapon))
    shield = Enum.find(worn, &(&1.kind == :shield))
    atk_spd = Formulas.atk_spd(a.dex, (weapon && weapon.atk_spd) || 300)
    cast_spd = Formulas.cast_spd(a.wit)
    bow? = weapon != nil and weapon.type == "bow"

    Map.merge(a, %{
      max_hp: Formulas.max_hp(Formulas.grown(set.hp, level), a.con),
      max_mp:
        Formulas.max_mp(Formulas.grown(set.mp, level), a.men) + Enum.sum_by(worn, &(&1.mp || 0)),
      p_atk: Formulas.p_atk((weapon && weapon.p_atk) || path.power, a.str, level),
      m_atk: Formulas.m_atk((weapon && weapon.m_atk) || path.magic, a.int, level),
      p_def: Formulas.p_def(covered(path.body, worn, player.path, [:chest, :legs]), level),
      m_def: Formulas.m_def(covered(path.mind, worn, :mind, [:necklace]), a.men, level),
      accuracy: Formulas.accuracy(a.dex, level) + ((weapon && weapon.accuracy) || 0),
      evasion: Formulas.evasion(a.dex, level),
      critical: Formulas.critical(a.dex, (weapon && weapon.critical) || 4),
      magic_critical: Formulas.magic_critical(a.wit),
      atk_spd: atk_spd,
      cast_spd: cast_spd,
      blows_per_round:
        if(bow?, do: Formulas.shots_per_round(atk_spd), else: Formulas.blows_per_round(atk_spd)),
      casts_per_round: Formulas.casts_per_round(cast_spd),
      hp_regen: Formulas.hp_regen(level, a.con),
      mp_regen: Formulas.mp_regen(level, a.men),
      weapon: weapon,
      shield: shield,
      spread: (weapon && weapon.spread) || Formulas.bare_spread(level)
    })
  end

  # Rules §23: the set's kit, its wearable part worn.
  defp kit(race_id, path) do
    {worn, carried} = Rules.kit(race_id, path)
    Enum.map(worn, &new_item(&1, true)) ++ Enum.map(carried, &new_item(&1, false))
  end

  @doc "An item picked up: a fresh id, the item's name, and whether it is on."
  def new_item(name, equipped \\ false),
    do: %{id: MiniLineage.Characters.Store.new_item_id(), name: name, equipped: equipped}

  @doc "Rules §25: the set's first skill, at the level the character knows it."
  def first_skill(player) do
    name = Rules.first_skill(player.race_id, player.path).name
    Rules.skill(name, Map.get(player.skills || %{}, name, 1))
  end

  @doc "Rules §23: the items a character has on, as `Rules` gives them."
  def worn(player),
    do: for(%{equipped: true, name: name} <- player.items || [], do: Rules.item(name))

  # Rules §7: the body or mind with each worn piece in place of the part it stands for.
  defp covered(total, worn, key, slots) do
    for item <- worn, item.slot in slots, reduce: total do
      acc -> acc - Rules.part(item.slot)[key] + Rules.counts_for(item)
    end
  end

  @doc "Both bars to the top, as a new character has them."
  def restore_fully(player) do
    stats = stats(player)
    %{player | health: stats.max_hp, mp: stats.max_mp}
  end

  @doc "Rules §12: EXP earned, and a level it reaches refills HP and MP."
  def gain_experience(player, amount) do
    gained = %{player | experience: player.experience + amount}
    if level(gained) > level(player), do: restore_fully(gained), else: gained
  end

  # -------------------------------------------------------------- conditions

  @doc """
  Rules §15 and §16: what the time and the place put on a character, as auras carrying their
  modifiers. A perk names its race in its own clause, so neither the hour nor the town alone can
  grant it.
  """
  def conditions(player) do
    night? = Clock.night?()

    [
      night? && :night,
      night? && player.race_id == @dark_elf && :shadow_sense,
      player.race_id == @elf && player.location == "elven-village" && :mother_tree
    ]
    |> Enum.filter(& &1)
    |> Enum.map(&Map.put(Constants.aura(&1), :modifiers, Rules.modifiers(&1)))
  end

  # ----------------------------------------------------------------- resting

  @doc """
  💤 always, a one-click hunt taking no time (rules §20), then whatever `conditions/1` puts on the character, and 🌿
  while a bar is short, carrying what one tick restores to each. The tick reads its rates from
  here, so the icon and the healing cannot disagree.
  """
  def auras(player) do
    conditions = conditions(player)
    stats = stats(player, conditions)

    healing =
      [{:hp_regen, player.health, stats.max_hp}, {:mp_regen, player.mp, stats.max_mp}]
      |> Enum.filter(fn {_key, now, max} -> now < max end)
      |> Enum.map(fn {key, _now, _max} -> {key, Math.js_round(stats[key])} end)

    regenerating =
      if healing == [], do: [], else: [Map.put(Constants.aura(:regenerating), :rates, healing)]

    [Constants.aura(:resting) | conditions] ++ regenerating
  end

  @doc "One 3-second tick of rules §11. Returns `{player, healed?}`."
  def regenerate(player) do
    stats = stats(player)

    case Enum.find(auras(player), &(&1.id == "regenerating")) do
      nil ->
        {player, false}

      %{rates: rates} ->
        hp = Keyword.get(rates, :hp_regen, 0)
        mp = Keyword.get(rates, :mp_regen, 0)

        {%{
           player
           | health: min(player.health + hp, stats.max_hp),
             mp: min(player.mp + mp, stats.max_mp)
         }, true}
    end
  end
end
