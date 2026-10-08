defmodule MiniLineage.Characters.Serde do
  @moduledoc """
  Converts a `%Player{}` to and from the JSON document stored in `characters.state`.

  Written out field by field rather than derived: the stored document is untrusted input, and
  every atom it turns back into is one this module names itself.
  """
  alias MiniLineage.Game.{Classes, Constants, Dyes, Player}

  # The shape of the document, not of the character. A reshape bumps this and `from_map/1` branches
  # on it; a document claiming a LATER one was written by a newer build, and must not be guessed at.
  @version 2

  # What version 1 drew a race's HP bar against, before classes: the only way to keep a stored run
  # at the same fraction of a bar that is now measured in Interlude's units.
  @legacy_max_hp %{0 => 100, 1 => 150, 2 => 75, 3 => 85}

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
      "coward" => p.coward,
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

    player = %Player{
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
      coward: m["coward"] == true,
      cheated: m["cheated"] == true,
      death_reason: m["death_reason"],
      total_battles: m["total_battles"] || 0,
      total_ambushes: m["total_ambushes"] || 0,
      consecutive_ambushes: m["consecutive_ambushes"] || 0,
      total_enemies_killed: m["total_enemies_killed"] || 0,
      effects: Enum.flat_map(m["effects"] || [], &effect_from_map/1),
      current_screen: m["current_screen"]
    }

    if version < 2, do: from_v1(player), else: player
  end

  def from_map(%{}),
    do: raise("character document carries no version; every one this build writes does")

  # A class the tree no longer has, or none at all, is its race's Fighter: what every run was.
  defp class_id(id, race_id) do
    case is_integer(id) && Classes.fetch(id) do
      {:ok, _class} -> id
      _ -> if race_id, do: Classes.starting(race_id, :fighter).id
    end
  end

  # Version 1 measured HP in the old race numbers; keep the run at the same fraction of its bar.
  defp from_v1(%Player{health: health, race_id: race_id} = player)
       when is_integer(health) and is_integer(race_id) do
    stats = Player.stats(player)
    added = player.effects |> Enum.flat_map(& &1.modifiers) |> Enum.filter(&(&1.type == :max_hp))
    old_max = Map.get(@legacy_max_hp, race_id, 100) + Enum.sum(Enum.map(added, & &1.value))
    health = if health <= 0, do: health, else: max(1, round(health / old_max * stats.max_hp))

    %{player | health: min(health, stats.max_hp), mp: stats.max_mp}
  end

  defp from_v1(player), do: player

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
