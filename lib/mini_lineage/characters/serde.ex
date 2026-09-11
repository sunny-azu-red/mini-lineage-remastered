defmodule MiniLineage.Characters.Serde do
  @moduledoc """
  Converts a `%Player{}` to and from the JSON document stored in `characters.state`.

  Written out field by field rather than derived: the stored document is untrusted input, and
  every atom it turns back into is one this module names itself.
  """
  alias MiniLineage.Game.Player

  # The shape of the document, not of the character — which is why it is written here rather than
  # carried on the struct. A reshape bumps this and `from_map/1` branches on it; today there is
  # only one shape, and a row written before versioning has it.
  @version 1

  @effect_types %{"buff" => :buff, "debuff" => :debuff, "aura" => :aura}
  @modifier_types ~w(attack defense crit max_health regen ambush_risk xp_multiplier adena_multiplier)a

  def to_map(%Player{} = p) do
    %{
      "version" => @version,
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
      "current_screen" => p.current_screen,
      "combat_until" => p.combat_until
      # `last_battle_narrative` is deliberately absent: it lives in battle_log now, and was half
      # the bytes of every save. The process rehydrates it from there when it starts.
    }
  end

  def from_map(%{} = m) do
    version = m["version"] || @version

    if version > @version do
      raise "character document is version #{version}; this build understands #{@version}"
    end

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
      current_screen: m["current_screen"],
      combat_until: m["combat_until"]
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
end
