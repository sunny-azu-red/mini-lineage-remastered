defmodule MiniLineage.Game.Snapshot do
  @moduledoc "The single Player -> view-model mapping."
  alias MiniLineage.Game.{Clock, Constants, Format, Math, Narrative, Player}

  def item_view(item) do
    modifiers = Map.get(item, :modifiers) || effect_modifiers(item)

    %{
      id: item.id,
      name: item.name,
      emoji: item.emoji,
      stat: item.stat,
      cost: item.cost,
      crit: modifier_value(modifiers, :crit),
      regen: modifier_value(modifiers, :regen),
      max_health: modifier_value(modifiers, :max_health)
    }
  end

  defp effect_modifiers(item) do
    case Map.get(item, :effect) do
      nil -> []
      key -> Constants.effect(key).modifiers
    end
  end

  defp modifier_value(modifiers, type) do
    Enum.find_value(modifiers, fn m -> if m.type == type, do: m.value end)
  end

  @doc """
  Always the SAME shape, whether or not a character exists: a screen still rendering when its
  character is reset would otherwise raise, and the LiveView silently remount.
  """
  @empty %{
    started: false,
    name: nil,
    race_id: nil,
    race_label: nil,
    race_emoji: nil,
    health: nil,
    max_health: nil,
    hp_percent: 0,
    low_health: false,
    experience: nil,
    level: nil,
    is_max_level: false,
    xp_current: 0,
    xp_required: 0,
    xp_percent: 0,
    xp_needed: 0,
    adena: nil,
    weapon: nil,
    armor: nil,
    stats: nil,
    effects: [],
    dead: false,
    ambushed: false,
    coward: false,
    cheated: false,
    death_reason: nil,
    ambush_low_health: nil,
    disqualified: false,
    counters: %{
      total_battles: 0,
      total_ambushes: 0,
      total_enemies_killed: 0
    },
    last_battle: nil
  }

  def build(player) do
    if Player.started?(player),
      do: started(player),
      else: @empty
  end

  defp started(player) do
    race = Constants.race(player.race_id)
    stats = Player.stats(player)
    level = Math.level_for_xp(player.experience)
    xp = Math.xp_progress(player.experience)

    %{
      started: true,
      name: player.name,
      race_id: player.race_id,
      race_label: race.label,
      race_emoji: race.emoji,
      health: player.health,
      max_health: stats.max_health,
      hp_percent: Math.percentage(player.health, stats.max_health),
      low_health: Math.low_health?(player.health, stats.max_health),
      experience: player.experience,
      level: level,
      is_max_level: Math.max_level?(level),
      xp_current: xp.current,
      xp_required: xp.required,
      xp_percent: xp.percent,
      xp_needed: Math.xp_needed_to_level_up(player.experience),
      adena: player.adena,
      weapon: item_view(Constants.weapon(player.weapon_id)),
      armor: item_view(Constants.armor(player.armor_id)),
      stats: stats,
      effects: Enum.map(Player.active_effects(player), &effect_view/1),
      dead: player.dead,
      ambushed: player.ambushed,
      coward: player.coward,
      cheated: player.cheated,
      death_reason: player.death_reason,
      ambush_low_health: Narrative.ambush_low_health(player),
      disqualified: player.coward or player.cheated,
      counters: %{
        total_battles: player.total_battles,
        total_ambushes: player.total_ambushes,
        total_enemies_killed: player.total_enemies_killed
      },
      last_battle: player.last_battle_narrative
    }
  end

  defp effect_view(effect) do
    %{
      id: effect.id,
      type: effect.type,
      emoji: effect.emoji,
      label: effect.label,
      tooltip: tooltip(effect),
      # Carried rather than only folded into the tooltip: the record explains an effect in prose,
      # and the derived regen aura's rate is only ever known here.
      modifiers: effect.modifiers,
      # A duration, not a deadline: the two machines' clocks never need reconciling.
      remaining_ms: effect.expires_at && max(0, effect.expires_at - Clock.now_ms())
    }
  end

  defp tooltip(%{modifiers: []} = effect), do: effect.label

  defp tooltip(effect),
    do: "#{effect.label} (#{Enum.map_join(effect.modifiers, ", ", &modifier_text/1)})"

  defp modifier_text(mod) do
    config = Map.get(Constants.stat_modifier_labels(), mod.type, %{label: to_string(mod.type)})

    if Map.get(config, :multiplier?) do
      "#{mod.value}x #{config.label}"
    else
      sign = if mod.value > 0, do: "+", else: ""
      unit = if Map.get(config, :percentage?), do: "%", else: ""
      "#{sign}#{mod.value}#{unit} #{config.label}"
    end
  end

  @catalog_key {__MODULE__, :catalog}

  @doc """
  The static catalog, built once per VM: slugifying and filling the race templates costs more than
  a whole view. Not cached in development, where an edited template must show without a restart.
  """
  def catalog do
    if Application.fetch_env!(:mini_lineage, :cache_catalog) do
      case :persistent_term.get(@catalog_key, nil) do
        nil -> tap(build_catalog(), &:persistent_term.put(@catalog_key, &1))
        catalog -> catalog
      end
    else
      build_catalog()
    end
  end

  defp build_catalog do
    %{
      races:
        Enum.map(Constants.races(), fn race ->
          Map.merge(race, %{
            slug: Format.slugify(race.label),
            traits: Narrative.build_race_traits(race)
          })
        end),
      weapons: Enum.map(Constants.weapons(), &item_view/1),
      armors: Enum.map(Constants.armors(), &item_view/1),
      foods: Enum.map(Constants.foods(), &item_view/1)
    }
  end
end
