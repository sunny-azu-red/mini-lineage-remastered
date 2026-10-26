defmodule MiniLineage.Game.Names do
  @moduledoc """
  How the game names an item or a skill, wherever it does: its emoji, then its name, in `.item` or
  `.skill`. A sentence (a flash, the fight log) takes `item/1` and `skill/2`; a page takes
  `MiniLineageWeb.Controls.item/1` and `skill/1`, which draw the same markup; an `<option>`, which
  holds none, takes the emoji and the name as text.
  """
  alias MiniLineage.Game.{Constants, Rules}

  # By what an item is (rules §23): a weapon by its type, anything else by its slot. No two things
  # the game names share an emoji, so a bow's 🏹 is never Power Shot's.
  @weapon_emojis %{
    "bow" => "🏹",
    "fists" => "🥊",
    "dagger" => "🔪",
    "staff" => "🪄",
    "sword" => "🗡️"
  }

  @slot_emojis %{
    shield: "🛡️",
    chest: "👕",
    legs: "👖",
    necklace: "📿",
    potion: "🧪"
  }

  # One each within a set, since a set learns two of a kind (the Orc Fighter, two physical
  # skills); a set's one heal wears the Mend orders' mark. An aura's is its effect's (`Constants`),
  # and a monster's spell is named by what it shows, Wind Strike sharing the character's.
  @mend "💚"
  @skill_emojis %{
    "Power Strike" => "💥",
    "Power Shot" => "🪶",
    "Mortal Blow" => "🎯",
    "Iron Punch" => "👊",
    "Wind Strike" => "🌪️",
    "Ice Bolt" => "❄️",
    "Vampiric Touch" => "🦇",
    "Chill Flame" => "🔥",
    "Drain Health" => "🩸",
    "Life Drain" => "🖤",
    "Self Heal" => @mend,
    "Heal" => @mend,
    "Elemental Heal" => @mend,
    "Curse: Poison" => "☠️",
    "Wind Shackle" => "⛓️",
    "Soul Cry" => "📢",
    "Armor Mastery" => "🪖",
    "Robe Mastery" => "👘",
    "Weapon Mastery" => "🤺",
    "Anti Magic" => "🧿",
    "HP Drain" => "🦟",
    "Aura Burn" => "♨️",
    "Prominence" => "☄️"
  }

  @doc "The mark every heal wears, in the log as in the Mend orders."
  def mend, do: @mend

  @doc "An item's emoji, from the item or its name."
  def item_emoji(name) when is_binary(name), do: item_emoji(Rules.item(name))
  def item_emoji(%{slot: :weapon, type: type}), do: Map.fetch!(@weapon_emojis, type)
  def item_emoji(%{slot: slot}), do: Map.fetch!(@slot_emojis, slot)

  @doc "A skill's emoji, or for one that raises an aura that aura's, as Buffs shows it."
  def skill_emoji(name) do
    case Map.fetch(@skill_emojis, name) do
      {:ok, emoji} -> emoji
      :error -> Constants.skill_aura(name).emoji
    end
  end

  @doc "An item named in a sentence, from the item or its name: `🗡️ Long Sword` in `.item`."
  def item(name) when is_binary(name), do: item(Rules.item(name))
  def item(item), do: ~s(<span class="item">#{item_emoji(item)} #{escape(item.name)}</span>)

  @doc "A skill named in a sentence, with its level when it has one: `🌪️ Wind Strike 2` in `.skill`."
  def skill(name, level \\ nil),
    do: ~s(<span class="skill">#{skill_emoji(name)} #{escape(name)}#{level && " #{level}"}</span>)

  # As HEEx escapes the same name on a page, so a sentence and a page write it alike ("Squire's").
  defp escape(text),
    do:
      text
      |> String.replace("&", "&amp;")
      |> String.replace("<", "&lt;")
      |> String.replace(">", "&gt;")
      |> String.replace(~s("), "&quot;")
      |> String.replace("'", "&#39;")
end
