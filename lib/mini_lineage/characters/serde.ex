defmodule MiniLineage.Characters.Serde do
  @moduledoc """
  Converts a `%Player{}` to and from the JSON document stored in `characters.state`.

  Written out field by field rather than derived: the stored document is untrusted input, and
  every atom it turns back into is one this module names itself.
  """
  alias MiniLineage.Game.Player

  @effect_types %{"buff" => :buff, "debuff" => :debuff, "aura" => :aura}
  @modifier_types ~w(attack defense crit max_health regen ambush_risk xp_multiplier adena_multiplier)a

  # Named once: these lists are both the shape written and the shape read back, and a key added to
  # one side alone would silently stop persisting.
  @narrative_keys ~w(crit_line kill_line deflection_line outcome_line ambush_line fight_prompt next_move)a
  @outcome_keys ~w(enemies_killed hp_lost damage_blocked xp_gained adena_gained is_critical is_level_up)a

  def to_map(%Player{} = p) do
    %{
      "name" => p.name,
      "race_id" => p.race_id,
      "health" => p.health,
      "adena" => p.adena,
      "experience" => p.experience,
      "weapon_id" => p.weapon_id,
      "armor_id" => p.armor_id,
      "dead" => p.dead,
      "ambushed" => p.ambushed,
      "coward" => p.coward,
      "cheated" => p.cheated,
      "death_reason" => p.death_reason,
      "total_battles" => p.total_battles,
      "total_ambushes" => p.total_ambushes,
      "consecutive_ambushes" => p.consecutive_ambushes,
      "total_enemies_killed" => p.total_enemies_killed,
      "effects" => Enum.map(p.effects, &effect_to_map/1),
      "revision" => p.revision,
      "current_screen" => p.current_screen,
      "combat_until" => p.combat_until,
      "last_battle_narrative" => battle_to_map(p.last_battle_narrative)
    }
  end

  def from_map(%{} = m) do
    %Player{
      name: m["name"],
      race_id: m["race_id"],
      health: m["health"],
      adena: m["adena"],
      experience: m["experience"],
      weapon_id: m["weapon_id"],
      armor_id: m["armor_id"],
      dead: m["dead"] == true,
      ambushed: m["ambushed"] == true,
      coward: m["coward"] == true,
      cheated: m["cheated"] == true,
      death_reason: m["death_reason"],
      total_battles: m["total_battles"] || 0,
      total_ambushes: m["total_ambushes"] || 0,
      consecutive_ambushes: m["consecutive_ambushes"] || 0,
      total_enemies_killed: m["total_enemies_killed"] || 0,
      effects: Enum.map(m["effects"] || [], &effect_from_map/1),
      revision: m["revision"] || 0,
      current_screen: m["current_screen"],
      combat_until: m["combat_until"],
      last_battle_narrative: battle_from_map(m["last_battle_narrative"])
    }
  end

  defp effect_to_map(e) do
    %{
      "id" => e.id,
      "type" => Atom.to_string(e.type),
      "group" => e.group,
      "emoji" => e.emoji,
      "label" => e.label,
      "modifiers" =>
        Enum.map(e.modifiers, &%{"type" => Atom.to_string(&1.type), "value" => &1.value}),
      "expires_at" => e.expires_at
    }
  end

  defp effect_from_map(e) do
    %{
      id: e["id"],
      type: Map.get(@effect_types, e["type"], :buff),
      group: e["group"],
      emoji: e["emoji"],
      label: e["label"],
      modifiers: Enum.flat_map(e["modifiers"] || [], &modifier_from_map/1),
      expires_at: e["expires_at"]
    }
  end

  defp modifier_from_map(%{"type" => type, "value" => value}) do
    case Enum.find(@modifier_types, &(Atom.to_string(&1) == type)) do
      nil -> []
      atom -> [%{type: atom, value: value}]
    end
  end

  defp modifier_from_map(_), do: []

  defp battle_to_map(nil), do: nil

  defp battle_to_map(b) do
    %{
      "narrative" => stringify(b.narrative, @narrative_keys),
      "outcome" => stringify(b.outcome, @outcome_keys),
      "ambushed" => b.ambushed,
      "died" => b.died,
      "sound" => b.sound
    }
  end

  defp battle_from_map(nil), do: nil

  defp battle_from_map(b) do
    %{
      narrative: atomize(b["narrative"], @narrative_keys),
      outcome: atomize(b["outcome"], @outcome_keys),
      ambushed: b["ambushed"] == true,
      died: b["died"] == true,
      sound: b["sound"]
    }
  end

  defp stringify(map, keys), do: Map.new(keys, &{Atom.to_string(&1), Map.get(map, &1)})
  defp atomize(nil, keys), do: Map.new(keys, &{&1, nil})
  defp atomize(map, keys), do: Map.new(keys, &{&1, Map.get(map, Atom.to_string(&1))})
end
