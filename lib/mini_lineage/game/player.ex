defmodule MiniLineage.Game.Player do
  @moduledoc """
  A character as the base layer (`docs/rules.md`) makes one, and what time does to it. Every
  function takes a player and returns a new one; nothing here touches a process or the database.
  """
  alias MiniLineage.Game.{Clock, Constants, Formulas, Math, Narrative, Rules}

  @elf 2
  # Rules §20: how long a character goes on not resting after it leaves the ground.
  @disengage_ms 5_000
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
            # Rules §23: what it carries, each `%{id, name, equipped, count}`. Stored in its own table.
            items: [],
            # Rules §25: each skill it knows, at the level it knows it.
            skills: %{},
            # Rules §20: "engaged" while it hunts, then the UTC millisecond its disengaging ends.
            combat: nil,
            # Rules §19: each aura it raised, to the UTC millisecond it fades.
            buffs: %{},
            # Rules §26: the share of its HP below which it drinks a potion in a fight; 0 never.
            potion_at: 50

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
          skills: first_skills(race.id, path)
      })

    began = Narrative.build_began(race, Rules.set(race.id, path).name)

    {player, %{text: Narrative.alert(began), type: :info, sound: "start"}}
  end

  @doc "Rules §25: what its trainer teaches at level 1 for nothing, a Mystic's first spell."
  def first_skills(race_id, path) do
    for lesson <- Rules.lessons(Rules.set(race_id, path).name),
        lesson.learn_at == 1 and lesson.sp == 0,
        into: %{},
        do: {lesson.skill, lesson.level}
  end

  # ------------------------------------------------------------------- stats

  def level(player), do: Math.level_for_xp(player.experience || 0)

  @doc """
  Every stat of rules §3 to §11, worked from the set the run started as and its level, then changed
  by whatever `conditions/1` puts on it.
  """
  def stats(player), do: stats(player, conditions(player))

  # Under conditions read once, so one call cannot straddle dusk.
  defp stats(player, conditions) do
    Enum.reduce(conditions, base_stats(player), fn aura, stats ->
      Enum.reduce(aura.modifiers, stats, &modify/2)
    end)
  end

  defp modify({stat, {:add, value}}, stats), do: Map.update!(stats, stat, &(&1 + value))
  defp modify({stat, {:mul, value}}, stats), do: Map.update!(stats, stat, &(&1 * value))

  defp base_stats(player) do
    set = Rules.set(player.race_id, player.path)
    path = Rules.path(player.path)
    a = set.attributes
    level = level(player)
    equipped = equipped(player)
    weapon = Enum.find(equipped, &(&1.kind == :weapon))
    shield = Enum.find(equipped, &(&1.kind == :shield))
    atk_spd = Formulas.atk_spd(a.dex, (weapon && weapon.atk_spd) || 300)
    cast_spd = Formulas.cast_spd(a.wit)
    bow? = weapon != nil and weapon.type == "bow"

    Map.merge(a, %{
      max_hp: Formulas.max_hp(Formulas.grown(set.hp, level), a.con),
      max_mp:
        Formulas.max_mp(Formulas.grown(set.mp, level), a.men) +
          Enum.sum_by(equipped, &(&1.mp || 0)),
      p_atk: Formulas.p_atk((weapon && weapon.p_atk) || path.power, a.str, level),
      m_atk: Formulas.m_atk((weapon && weapon.m_atk) || path.magic, a.int, level),
      p_def: Formulas.p_def(covered(path.body, equipped, player.path, [:chest, :legs]), level),
      m_def: Formulas.m_def(covered(path.mind, equipped, :mind, [:necklace]), a.men, level),
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

  # Rules §23: the set's kit, its wearable part equipped.
  defp kit(race_id, path) do
    {equipped, carried} = Rules.kit(race_id, path)
    Enum.map(equipped, &new_item(&1, true)) ++ Enum.map(carried, &new_item(&1, false))
  end

  @doc "An item picked up: a fresh id, the item's name, whether it is on, and how many (§26)."
  def new_item(name, equipped \\ false, count \\ 1),
    do: %{
      id: MiniLineage.Characters.Store.new_item_id(),
      name: name,
      equipped: equipped,
      count: count
    }

  @doc "Rules §26: the potions it carries, as a fight drinks them, strongest first."
  def potions(player) do
    for(
      entry <- player.items || [],
      item = Rules.item(entry.name),
      Rules.stacks?(item),
      do: %{name: entry.name, heals: item.heals, count: Map.get(entry, :count, 1)}
    )
    |> Enum.sort_by(& &1.heals, :desc)
  end

  @doc "Rules §26: the potions a fight drank, taken from their stacks; an empty stack goes."
  def drink_down(player, drunk) do
    items =
      player.items
      |> Enum.map(fn entry ->
        case drunk[entry.name] do
          nil -> entry
          n -> %{entry | count: Map.get(entry, :count, 1) - n}
        end
      end)
      |> Enum.filter(&(Map.get(&1, :count, 1) > 0))

    %{player | items: items}
  end

  @doc "Rules §26: the shares a player may choose to drink a potion below."
  def potion_shares, do: [0, 30, 50, 70]

  @doc "Rules §19: every skill it knows, each at the level it knows it."
  def known_skills(player),
    do: for({name, level} <- player.skills || %{}, do: Rules.skill(name, level))

  @doc "Rules §25: the set's first skill, at the level the character knows it."
  def first_skill(player) do
    name = Rules.first_skill(player.race_id, player.path).name
    Rules.skill(name, Map.get(player.skills || %{}, name, 1))
  end

  @doc "Rules §23: the items a character has on, as `Rules` gives them."
  def equipped(player),
    do: for(%{equipped: true, name: name} <- player.items || [], do: Rules.item(name))

  # Rules §7: the body or mind with each equipped piece in place of the part it stands for.
  defp covered(total, equipped, key, slots) do
    for item <- equipped, item.slot in slots, reduce: total do
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
    |> Kernel.++(raised(player))
  end

  # Rules §19: an aura the character raised, until it fades.
  defp raised(player) do
    for name <- buffs_up(player) do
      skill = Rules.skill(name)
      Map.put(Constants.skill_aura(name), :modifiers, [{skill.stat, {:mul, skill.times}}])
    end
  end

  @doc "Rules §19: the auras it raised that have not faded yet."
  def buffs_up(player) do
    now = now_ms()
    for {name, fades} <- player.buffs || %{}, fades > now, do: name
  end

  @doc "Rules §19: auras just raised, each fading `lasts` from now; any that already faded go."
  def put_buffs(player, names) do
    now = now_ms()
    kept = Map.filter(player.buffs || %{}, fn {_, fades} -> fades > now end)
    %{player | buffs: Map.merge(kept, Map.new(names, &{&1, now + Rules.skill(&1).lasts}))}
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

    if in_combat?(player),
      do: [Constants.aura(:combat) | conditions],
      else: resting_auras(player, conditions, stats)
  end

  defp resting_auras(player, conditions, stats) do
    healing =
      [{:hp_regen, player.health, stats.max_hp}, {:mp_regen, player.mp, stats.max_mp}]
      |> Enum.filter(fn {_key, now, max} -> now < max end)
      |> Enum.map(fn {key, _now, _max} -> {key, Math.js_round(stats[key])} end)

    regenerating =
      if healing == [], do: [], else: [Map.put(Constants.aura(:regenerating), :rates, healing)]

    [Constants.aura(:resting) | conditions] ++ regenerating ++ relaxing(player, stats)
  end

  # Rules §11: Relax mends more HP for MP, while HP is short and the MP lasts.
  defp relaxing(player, stats) do
    case player.skills["Relax"] do
      nil ->
        []

      level ->
        relax = Rules.skill("Relax", level)

        if player.health < stats.max_hp and player.mp >= relax.mp,
          do: [
            Map.put(Constants.skill_aura("Relax"), :rates,
              hp_regen: relax.power,
              mp_regen: -relax.mp
            )
          ],
          else: []
    end
  end

  @doc "Rules §20: whether a character is engaged, or still disengaging, and so does not rest."
  def in_combat?(%{combat: "engaged"}), do: true
  def in_combat?(%{combat: until}) when is_integer(until), do: until > now_ms()
  def in_combat?(_player), do: false

  @doc "Rules §20: leaving the ground; resting resumes once the disengaging is over."
  def disengage(%{combat: "engaged"} = player), do: %{player | combat: now_ms() + @disengage_ms}
  def disengage(player), do: player

  defp now_ms, do: DateTime.to_unix(Clock.now(), :millisecond)

  @doc "One 3-second tick of rules §11. Returns `{player, healed?}`."
  def regenerate(%{combat: until} = player) when is_integer(until) do
    # A disengaging that has run out is forgotten, and this tick rests.
    if in_combat?(player), do: {player, false}, else: regenerate(%{player | combat: nil})
  end

  def regenerate(player) do
    stats = stats(player)
    # An aura that has faded goes, and the page is told.
    faded? = length(buffs_up(player)) < map_size(player.buffs || %{})
    player = if faded?, do: put_buffs(player, []), else: player

    case auras(player) |> Enum.flat_map(&Map.get(&1, :rates, [])) do
      [] ->
        {player, faded?}

      rates ->
        hp = rates |> Keyword.get_values(:hp_regen) |> Enum.sum()
        mp = rates |> Keyword.get_values(:mp_regen) |> Enum.sum()

        {%{
           player
           | health: min(player.health + hp, stats.max_hp),
             mp: player.mp |> Kernel.+(mp) |> min(stats.max_mp) |> max(0)
         }, true}
    end
  end
end
