defmodule MiniLineage.Game.Snapshot do
  @moduledoc "The single Player -> view-model mapping. Reuses the math and player modules."
  alias MiniLineage.Game.{Constants, Format, Math, Player}

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
  Always the SAME shape, whether or not a character exists. A view missing keys means any screen
  still rendering when a character is reset — in this tab or another — raises instead of drawing,
  and the LiveView silently remounts, swallowing whatever it was about to say.
  """
  @empty %{
    started: false,
    revision: 0,
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
    highscore_eligible: false,
    counters: %{
      total_battles: 0,
      total_ambushes: 0,
      consecutive_ambushes: 0,
      total_enemies_killed: 0
    },
    last_battle: nil
  }

  def build(player) do
    if Player.started?(player),
      do: started(player),
      else: %{@empty | revision: player.revision}
  end

  defp started(player) do
    race = Constants.race(player.race_id)
    stats = Player.stats(player)
    level = Math.level_for_xp(player.experience)
    xp = Math.xp_progress(player.experience)

    %{
      started: true,
      revision: player.revision,
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
      highscore_eligible: player.dead and not player.coward and not player.cheated,
      counters: %{
        total_battles: player.total_battles,
        total_ambushes: player.total_ambushes,
        consecutive_ambushes: player.consecutive_ambushes,
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
      # A duration, not a deadline: the two machines' clocks never need reconciling.
      remaining_ms:
        effect.expires_at && max(0, effect.expires_at - MiniLineage.Game.Clock.now_ms())
    }
  end

  defp tooltip(%{modifiers: []} = effect), do: effect.label

  defp tooltip(effect),
    do: "#{effect.label} (#{Enum.map_join(effect.modifiers, ", ", &modifier_text/1)})"

  defp modifier_text(mod) do
    config = Map.get(Constants.stat_modifier_labels(), mod.type, %{label: to_string(mod.type)})

    cond do
      Map.get(config, :multiplier?) ->
        "#{mod.value}x #{config.label}"

      true ->
        sign = if mod.value > 0, do: "+", else: ""
        unit = if Map.get(config, :percentage?), do: "%", else: ""
        "#{sign}#{mod.value}#{unit} #{config.label}"
    end
  end

  @doc "The static catalog. Nothing in it changes at runtime."
  def catalog do
    %{
      races:
        Enum.map(Constants.races(), fn race ->
          Map.merge(race, %{
            slug: Format.slugify(race.label),
            traits: MiniLineage.Game.Narrative.build_race_traits(race)
          })
        end),
      weapons: Enum.map(Constants.weapons(), &item_view/1),
      armors: Enum.map(Constants.armors(), &item_view/1),
      foods: Enum.map(Constants.foods(), &item_view/1)
    }
  end
end
