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
            location: nil

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
          adena: 0,
          location: Rules.hometown(race.id)
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
    atk_spd = Formulas.atk_spd(a.dex)
    cast_spd = Formulas.cast_spd(a.wit)

    Map.merge(a, %{
      max_hp: Formulas.max_hp(Formulas.grown(set.hp, level), a.con),
      max_mp: Formulas.max_mp(Formulas.grown(set.mp, level), a.men),
      p_atk: Formulas.p_atk(path.power, a.str, level),
      m_atk: Formulas.m_atk(path.magic, a.int, level),
      p_def: Formulas.p_def(path.body, level),
      m_def: Formulas.m_def(path.mind, a.men, level),
      accuracy: Formulas.accuracy(a.dex, level),
      evasion: Formulas.evasion(a.dex, level),
      critical: Formulas.critical(a.dex),
      magic_critical: Formulas.magic_critical(a.wit),
      atk_spd: atk_spd,
      cast_spd: cast_spd,
      blows_per_round: Formulas.blows_per_round(atk_spd),
      casts_per_round: Formulas.casts_per_round(cast_spd),
      hp_regen: Formulas.hp_regen(level, a.con),
      mp_regen: Formulas.mp_regen(level, a.men)
    })
  end

  @doc "Both bars to the top, as a new character has them."
  def restore_fully(player) do
    stats = stats(player)
    %{player | health: stats.max_hp, mp: stats.max_mp}
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
  💤 always, there being no combat yet, then whatever `conditions/1` puts on the character, and 🌿
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
