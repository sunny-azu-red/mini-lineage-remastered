defmodule MiniLineage.Characters.Serde do
  @moduledoc """
  Converts a `%Player{}` to and from the JSON document stored in `characters.state`.

  Written out field by field rather than derived: the stored document is untrusted input, and
  every atom it turns back into is one this module names itself.
  """
  alias MiniLineage.Game.{Player, Rules}

  # The shape of the document, not of the character. A reshape bumps this and `from_map/1` branches
  # on it; a document claiming a LATER one was written by a newer build, and must not be guessed at.
  @version 2

  def to_map(%Player{} = p) do
    %{
      "version" => @version,
      "name" => p.name,
      "race_id" => p.race_id,
      "path" => p.path && Atom.to_string(p.path),
      "health" => p.health,
      "mp" => p.mp,
      "adena" => p.adena,
      "experience" => p.experience,
      "sp" => p.sp,
      "location" => p.location,
      "dead" => p.dead,
      "killer" => p.killer
    }
  end

  def from_map(%{"version" => version} = m) do
    if version > @version do
      raise "character document is version #{version}; this build understands #{@version}"
    end

    %Player{
      name: m["name"],
      race_id: m["race_id"],
      path: path(m["path"]),
      health: m["health"],
      mp: m["mp"],
      adena: m["adena"],
      experience: m["experience"],
      # Earned from the first hunt on; a run from before it has none yet.
      sp: m["sp"] || if(m["race_id"], do: 0),
      location: location(m["location"], m["race_id"]),
      dead: m["dead"] == true,
      killer: m["killer"]
    }
  end

  def from_map(%{}),
    do: raise("character document carries no version; every one this build writes does")

  # A town renamed keeps whoever stands in it; anything else stored under an old slug would be sent
  # home without a word.
  @renamed %{"dark-elven-village" => "dark-elf-village"}

  # Version 1 had no location, every character being in its village; and a slug this build does not
  # know is put back there too, rather than handed to a lookup that would raise on it.
  defp location(slug, race_id) do
    slug = Map.get(@renamed, slug, slug)

    cond do
      is_binary(slug) and Rules.town?(slug) and Rules.town(slug).open? -> slug
      race_id != nil -> Rules.hometown(race_id)
      true -> nil
    end
  end

  defp path("fighter"), do: :fighter
  defp path("mystic"), do: :mystic
  defp path(_unknown), do: nil
end
