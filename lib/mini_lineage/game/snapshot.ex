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
    race_emoji: nil,
    class_name: nil,
    town: nil,
    routes: [],
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
      race_emoji: race.emoji,
      class_name: Rules.set(player.race_id, player.path).name,
      town:
        Map.put(
          Rules.town(player.location),
          :description,
          Constants.town_description(player.location)
        ),
      routes: routes(player.location),
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

  # What the Gatekeeper offers: each town a route reaches, with the fee for it.
  defp routes(from),
    do: Enum.map(Rules.routes_from(from), &Map.put(Rules.town(&1.to), :fee, &1.fee))

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

  @doc "Every race as the Chronicles of Ancestry draws it: its town and its two level-1 sets."
  def catalog do
    %{
      races:
        Enum.map(Constants.races(), fn race ->
          Map.merge(race, %{
            slug: Format.slugify(race.label),
            town: Rules.town(Rules.hometown(race.id)),
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
