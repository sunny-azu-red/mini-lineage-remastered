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
      "killer" => p.killer,
      "skills" => p.skills,
      "combat" => p.combat,
      "buffs" => p.buffs,
      "potion_at" => p.potion_at
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
      killer: m["killer"],
      skills: skills(m["skills"], m["race_id"], path(m["path"])),
      combat: combat(m["combat"]),
      buffs: buffs(m["buffs"]),
      potion_at:
        if(m["potion_at"] in Player.potion_shares(),
          do: m["potion_at"],
          else: %Player{}.potion_at
        )
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

  # Only the names `Rules` knows, at whole levels; a run from before the trainer knows its first skill.
  defp skills(%{} = known, _race_id, _path),
    do:
      for(
        {name, level} <- known,
        Rules.skill_known?(name),
        is_integer(level),
        into: %{},
        do: {name, level}
      )

  defp skills(_none, race_id, path) when is_integer(race_id) and path in [:fighter, :mystic],
    do: %{Rules.first_skill(race_id, path).name => 1}

  defp skills(_none, _race_id, _path), do: %{}

  # Only auras `Rules` knows, each to a whole millisecond; a run from before them raised none.
  defp buffs(%{} = raised),
    do:
      for(
        {name, fades} <- raised,
        Map.has_key?(Rules.skills(), name) and Rules.skill(name).kind == :aura,
        is_integer(fades),
        into: %{},
        do: {name, fades}
      )

  defp buffs(_none), do: %{}

  defp combat("engaged"), do: "engaged"
  defp combat(until) when is_integer(until), do: until
  defp combat(_none), do: nil

  defp path("fighter"), do: :fighter
  defp path("mystic"), do: :mystic
  defp path(_unknown), do: nil
end
