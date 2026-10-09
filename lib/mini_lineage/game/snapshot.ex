defmodule MiniLineage.Game.Snapshot do
  @moduledoc "The single Player -> view-model mapping, and the static catalog the pages draw from."
  alias MiniLineage.Game.{Constants, Format, Formulas, Math, Player, Rules}

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
    class_name: nil,
    town: nil,
    health: nil,
    max_health: nil,
    mp: nil,
    max_mp: nil,
    level: nil,
    is_max_level: false,
    experience: nil,
    xp_current: 0,
    xp_required: 0,
    adena: nil,
    stats: nil,
    effects: []
  }

  def build(player) do
    if Player.started?(player), do: started(player), else: @empty
  end

  defp started(player) do
    race = Constants.race(player.race_id)
    stats = Player.stats(player)
    level = Player.level(player)
    current = Math.xp_for_level(level)

    %{
      started: true,
      name: player.name,
      race_id: player.race_id,
      race_label: race.label,
      race_emoji: race.emoji,
      class_name: Rules.set(player.race_id, player.path).name,
      town: Map.put(Rules.town(player.race_id), :description, race.hometown),
      health: player.health,
      max_health: stats.max_hp,
      mp: player.mp,
      max_mp: stats.max_mp,
      level: level,
      is_max_level: Math.max_level?(level),
      experience: player.experience,
      xp_current: player.experience - current,
      xp_required:
        if(Math.max_level?(level), do: 0, else: Math.xp_for_level(level + 1) - current),
      adena: player.adena,
      stats: stats,
      effects: Enum.map(Player.auras(player), &aura_view/1)
    }
  end

  # 🌿 says what it is restoring, and how much a tick.
  defp aura_view(aura) do
    rates = Map.get(aura, :rates, [])

    tooltip =
      case rates do
        [] -> aura.label
        _ -> "#{aura.label} (#{Enum.map_join(rates, ", ", &rate_text/1)})"
      end

    %{id: aura.id, type: aura.type, emoji: aura.emoji, label: aura.label, tooltip: tooltip}
  end

  defp rate_text({:hp_regen, value}), do: "+#{value} HP"
  defp rate_text({:mp_regen, value}), do: "+#{value} MP"

  @catalog_key {__MODULE__, :catalog}

  @doc """
  The static catalog, built once per VM. Not cached in development, where an edited template must
  show without a restart.
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
            town: Rules.town(race.id),
            classes: Enum.map([:fighter, :mystic], &born(Rules.set(race.id, &1)))
          })
        end)
    }
  end

  # What a starting set is born with: its attributes, and the HP and MP they make of level 1.
  defp born(set) do
    a = set.attributes

    %{
      name: set.name,
      path: set.path,
      attributes: a,
      max_hp: Formulas.max_hp(Formulas.grown(set.hp, 1), a.con),
      max_mp: Formulas.max_mp(Formulas.grown(set.mp, 1), a.men)
    }
  end
end
