defmodule MiniLineage.Characters.Serde do
  @moduledoc """
  Converts a `%Player{}` to and from the JSON document stored in `characters.state`.

  Written out field by field rather than derived: the stored document is untrusted input, and
  every atom it turns back into is one this module names itself.
  """
  alias MiniLineage.Game.{Classes, Constants, Dyes, Player}

  # The shape of the document, not of the character. A reshape bumps this and `from_map/1` branches
  # on it; a document claiming a LATER one was written by a newer build, and must not be guessed at.
  @version 1

  def to_map(%Player{} = p) do
    %{
      "version" => @version,
      "name" => p.name,
      "race_id" => p.race_id,
      "class_id" => p.class_id,
      "health" => p.health,
      "mp" => p.mp,
      "adena" => p.adena,
      "experience" => p.experience,
      "weapon_id" => p.weapon_id,
      "armor_id" => p.armor_id,
      "dyes" => p.dyes,
      "dead" => p.dead,
      "ambushed" => p.ambushed,
      "cheated" => p.cheated,
      "death_reason" => p.death_reason,
      "total_battles" => p.total_battles,
      "total_ambushes" => p.total_ambushes,
      "consecutive_ambushes" => p.consecutive_ambushes,
      "total_enemies_killed" => p.total_enemies_killed,
      "effects" => Enum.map(p.effects, &effect_to_map/1),
      "current_screen" => p.current_screen
      # `last_battle_narrative` is absent: it lives in character_log, and the process rehydrates it.
    }
  end

  def from_map(%{"version" => version} = m) do
    if version > @version do
      raise "character document is version #{version}; this build understands #{@version}"
    end

    %Player{
      name: m["name"],
      race_id: m["race_id"],
      class_id: class_id(m["class_id"], m["race_id"]),
      health: m["health"],
      mp: m["mp"],
      adena: m["adena"],
      experience: m["experience"],
      weapon_id: m["weapon_id"],
      armor_id: m["armor_id"],
      dyes: Enum.filter(m["dyes"] || [], &match?({:ok, _}, Dyes.fetch(&1))),
      dead: m["dead"] == true,
      ambushed: m["ambushed"] == true,
      cheated: m["cheated"] == true,
      death_reason: m["death_reason"],
      total_battles: m["total_battles"] || 0,
      total_ambushes: m["total_ambushes"] || 0,
      consecutive_ambushes: m["consecutive_ambushes"] || 0,
      total_enemies_killed: m["total_enemies_killed"] || 0,
      effects: Enum.flat_map(m["effects"] || [], &effect_from_map/1),
      current_screen: m["current_screen"]
    }
  end

  def from_map(%{}),
    do: raise("character document carries no version; every one this build writes does")

  # A class the tree does not have is its race's Fighter, rather than a guess at another.
  defp class_id(id, race_id) do
    case is_integer(id) && Classes.fetch(id) do
      {:ok, _class} -> id
      _ -> if race_id, do: Classes.starting(race_id, :fighter).id
    end
  end

  # Which effect, and until when: everything else is the catalog's, so a retuned effect reaches the
  # runs already carrying it.
  defp effect_to_map(e), do: %{"id" => e.id, "expires_at" => e.expires_at}

  # An id the catalog does not have names nothing, and is dropped rather than guessed at.
  defp effect_from_map(%{"id" => id} = e) do
    case Constants.effect_by_id(id) do
      nil -> []
      config -> [Player.to_active(config, e["expires_at"])]
    end
  end

  defp effect_from_map(_malformed), do: []
end
