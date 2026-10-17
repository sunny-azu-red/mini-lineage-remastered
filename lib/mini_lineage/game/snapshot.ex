defmodule MiniLineage.Game.Snapshot do
  @moduledoc "The single Player -> view-model mapping, and the static catalog the pages draw from."
  alias MiniLineage.Game.{Clock, Constants, Format, Formulas, Math, Player, Rules, Shop}

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
    path: nil,
    town: nil,
    ground: nil,
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
    traders: nil,
    guild: nil,
    lessons: [],
    skills: [],
    potion_at: nil,
    heals?: false,
    heal_pull_at: nil,
    heal_fight_at: nil,
    unused: [],
    switchable: [],
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
      path: player.path,
      town:
        Map.put(
          Rules.town(player.location),
          :description,
          Constants.town_description(player.location)
        ),
      # Rules §17: the ground outside the village, if it stands in one.
      ground: Rules.ground_of(player.location),
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
      # Rules §23: what it carries, equipped first in slot order, then the rest as picked up.
      items: items(player),
      # Rules §24: the village's shop, where there is one, showing the path its own goods.
      stock: if(Rules.village?(player.location), do: stock(player), else: []),
      traders: if(Rules.village?(player.location), do: Rules.traders(player.location)),
      # Rules §25: the guild's lessons, in the character's own village only.
      guild: Rules.guild(Rules.set(player.race_id, player.path).name),
      lessons:
        if(player.location == Rules.hometown(player.race_id),
          do: lessons(player, level),
          else: []
        ),
      # The guild's shelves, Active before Passive, each by name.
      skills:
        Enum.sort_by(player.skills, fn {name, _} -> {Rules.skill(name).kind == :passive, name} end),
      potion_at: player.potion_at,
      # Rules §20: the orders, given only by a character that knows a heal.
      heals?: Player.heals?(player),
      heal_pull_at: player.heal_pull_at,
      heal_fight_at: player.heal_fight_at,
      # Rules §20: the skills its orders leave unused, and those they may.
      unused: player.unused,
      switchable: Player.switchable(player),
      stats: stats,
      effects: Enum.map(Player.auras(player), &aura_view/1)
    }
  end

  @slots ~w(weapon shield necklace chest legs)a

  defp items(player) do
    player.items
    |> Enum.map(fn entry ->
      item = Rules.item(entry.name)

      %{
        id: entry.id,
        name: entry.name,
        equipped: entry.equipped,
        count: Map.get(entry, :count, 1),
        potion?: Rules.stacks?(item),
        slot: item.slot,
        type: item.type,
        hands: item[:hands],
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

  defp stock(player),
    do:
      Enum.map(
        Rules.stock(player.location, Rules.set(player.race_id, player.path)),
        &%{
          name: &1.name,
          slot: &1.slot,
          type: &1.type,
          hands: &1[:hands],
          about: about(&1),
          price: Shop.price(&1)
        }
      )

  defp lessons(player, level) do
    for lesson <- Rules.lessons(Rules.set(player.race_id, player.path).name) do
      known = Map.get(player.skills, lesson.skill, 0)

      status =
        cond do
          known >= lesson.level -> :known
          level < lesson.learn_at -> :later
          known != lesson.level - 1 -> :queued
          true -> :ready
        end

      Map.put(lesson, :status, status)
    end
  end

  defp slot_index(slot), do: Enum.find_index(@slots, &(&1 == slot))

  @doc "An item's numbers in a line: what it is, then what it gives."
  def about(%{kind: :potion} = item), do: "Mends #{item.heals} HP at once"

  # An item's own numbers follow their stat ("P. Atk. 6"), and what it adds to yours leads it
  # ("-3 Accuracy"), as a buff writes it. A rate keeps its %.
  def about(item) do
    # Rules §7: a piece of armour shows what it counts for, which is what it gives.
    counts = if item.slot in [:chest, :legs, :necklace], do: round(Rules.counts_for(item))

    [
      p_atk: Format.stat(:p_atk),
      m_atk: Format.stat(:m_atk),
      atk_spd: Format.stat(:atk_spd),
      critical: Format.stat(:critical),
      # Rules §13: how far each blow strays either way.
      spread: "Damage ±",
      accuracy: Format.stat(:accuracy),
      p_def: Format.stat(:p_def),
      m_def: Format.stat(:m_def),
      shield_def: Format.stat(:shield_def),
      shield_rate: Format.stat(:shield_rate),
      evasion: Format.stat(:evasion),
      mp: Format.stat(:mp)
    ]
    |> Enum.filter(fn {key, _} -> item[key] not in [nil, 0] end)
    |> Enum.map(fn
      {key, label} when key in [:critical, :shield_rate] ->
        "#{label} #{item[key]}%"

      {:spread, label} ->
        "#{label}#{item.spread}%"

      {key, label} when key in [:accuracy, :evasion, :mp] ->
        "#{signed(item[key])} #{label}"

      {key, label} when key in [:p_def, :m_def] ->
        "#{label} #{counts || item[key]}"

      {key, label} ->
        "#{label} #{item[key]}"
    end)
    |> Enum.join(", ")
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
        Enum.map(Map.get(aura, :modifiers, []), &%{stat: elem(&1, 0), text: modifier_text(&1)}),
      # Rules §11: what a tick of rest mends (or Relax costs), said on the row as in the tooltip.
      rates:
        Enum.map(Map.get(aura, :rates, []), fn {stat, value} -> %{stat: stat, value: value} end),
      # A duration, not a deadline, so the browser's clock is never compared with the server's.
      remaining_ms:
        aura[:ends_at] && max(aura.ends_at - DateTime.to_unix(Clock.now(), :millisecond), 0),
      # Which countdown this is, and nothing about when: the browser counts each from the first
      # duration it is sent, so a server clock that steps cannot move one already counting.
      timer_key: aura[:ends_at] && Integer.to_string(:erlang.phash2({aura.id, aura.ends_at}))
    }
  end

  defp rate_text({:hp_regen, value}), do: "#{signed(value)} HP"
  defp rate_text({:mp_regen, value}), do: "#{signed(value)} MP"

  defp signed(value) when value >= 0, do: "+#{value}"
  defp signed(value), do: "#{value}"

  defp modifier_text({stat, {:add, value}}), do: "#{signed(value)} #{Format.stat(stat)}"
  # As Lineage II's own data writes a buff: "+8% P. Def.", never "×1.08".
  defp modifier_text({stat, {:mul, value}}),
    do: "#{signed(round((value - 1) * 100))}% #{Format.stat(stat)}"

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
