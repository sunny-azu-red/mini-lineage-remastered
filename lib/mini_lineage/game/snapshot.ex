defmodule MiniLineage.Game.Snapshot do
  @moduledoc "The single Player -> view-model mapping, and the static catalog the pages draw from."
  alias MiniLineage.Game.{Constants, Format, Formulas, Math, Player, Rules, Shop}

  @doc """
  Always the SAME shape, whether or not a character exists: a screen still rendering when its
  character is reset would otherwise raise, and the LiveView silently remount.
  """
  @empty %{
    started: false,
    name: nil,
    race_emoji: nil,
    ancestry: nil,
    perk: nil,
    class_name: nil,
    town: nil,
    ground: nil,
    skill: nil,
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
    sp: nil,
    items: [],
    stock: [],
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
      ancestry: race.label,
      perk: race.perk,
      class_name: Rules.set(player.race_id, player.path).name,
      town:
        Map.put(
          Rules.town(player.location),
          :description,
          Constants.town_description(player.location)
        ),
      # Rules §17: the ground outside the village, if it stands in one.
      ground: Rules.ground_of(player.location),
      skill: Rules.first_skill(player.race_id, player.path),
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
      sp: player.sp || 0,
      # Rules §23: what it carries, worn first in slot order, then the rest as picked up.
      items: items(player),
      # Rules §24: the village's shop, where there is one.
      stock: if(Rules.village?(player.location), do: stock(player.location), else: []),
      stats: stats,
      effects: Enum.map(Player.auras(player), &aura_view/1)
    }
  end

  @slots ~w(weapon shield head chest legs gloves feet necklace earring ring)a

  defp items(player) do
    player.items
    |> Enum.map(fn entry ->
      item = Rules.item(entry.name)

      %{
        id: entry.id,
        name: entry.name,
        equipped: entry.equipped,
        slot: item.slot,
        about: about(item),
        buyback: Shop.buyback(item)
      }
    end)
    |> Enum.with_index()
    |> Enum.sort_by(fn {i, n} ->
      {!i.equipped, if(i.equipped, do: slot_index(i.slot), else: n)}
    end)
    |> Enum.map(&elem(&1, 0))
  end

  defp stock(town),
    do:
      Enum.map(
        Rules.stock(town),
        &%{name: &1.name, slot: &1.slot, about: about(&1), price: Shop.price(&1)}
      )

  defp slot_index(slot), do: Enum.find_index(@slots, &(&1 == slot))

  @doc "An item's numbers in a line: what it is, then what it gives."
  def about(item) do
    stats =
      [
        p_atk: "P.Atk",
        m_atk: "M.Atk",
        atk_spd: "Atk. Spd.",
        critical: "Critical",
        p_def: "P.Def",
        m_def: "M.Def",
        shield_def: "Shield",
        shield_rate: "Block",
        mp: "MP"
      ]
      |> Enum.filter(fn {key, _} -> item[key] end)
      |> Enum.map(fn
        {:shield_rate, label} -> "#{label} #{item.shield_rate}%"
        {:mp, label} -> "#{label} +#{item.mp}"
        {key, label} -> "#{label} #{item[key]}"
      end)

    kind =
      cond do
        item.kind == :weapon -> "#{if item.hands == 2, do: "two-handed ", else: ""}#{item.type}"
        true -> Atom.to_string(item.slot)
      end

    Enum.join([kind | stats], ", ")
  end

  # What the Gatekeeper offers: each town a route reaches, with the fee for it.
  defp routes(from),
    do: Enum.map(Rules.routes_from(from), &Map.put(Rules.town(&1.to), :fee, &1.fee))

  # 🌿 says what it is restoring, and how much a tick; night and a perk what they change.
  defp aura_view(aura) do
    parts =
      Enum.map(Map.get(aura, :rates, []), &rate_text/1) ++
        Enum.map(Map.get(aura, :modifiers, []), &modifier_text/1)

    tooltip = if parts == [], do: aura.label, else: "#{aura.label} (#{Enum.join(parts, ", ")})"

    %{
      id: aura.id,
      type: aura.type,
      emoji: aura.emoji,
      label: aura.label,
      tooltip: tooltip,
      about: aura.about,
      # A rate is drawn as a figure beside the stats; a modifier is a rule, and never moves. The
      # stat rides along so the page can colour the change as it colours the stat.
      changes:
        Enum.map(Map.get(aura, :modifiers, []), &%{stat: elem(&1, 0), text: modifier_text(&1)})
    }
  end

  defp rate_text({:hp_regen, value}), do: "+#{value} HP"
  defp rate_text({:mp_regen, value}), do: "+#{value} MP"

  @stat_names %{accuracy: "Accuracy", hp_regen: "HP regen", mp_regen: "MP regen"}

  defp modifier_text({stat, {:add, value}}) when value >= 0, do: "+#{value} #{@stat_names[stat]}"
  defp modifier_text({stat, {:add, value}}), do: "#{value} #{@stat_names[stat]}"
  defp modifier_text({stat, {:mul, value}}), do: "×#{value} #{@stat_names[stat]}"

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
