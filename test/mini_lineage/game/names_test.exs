defmodule MiniLineage.Game.NamesTest do
  @moduledoc """
  How the game names an item or a skill: one emoji each, never another thing's, and one markup in
  a sentence, `.item` or `.skill` led by it.
  """
  use ExUnit.Case, async: true

  alias MiniLineage.Game.{Constants, Names, Rules}

  @conditions ~w(combat resting night shadow_sense mother_tree regenerating ghost)a

  defp items, do: Map.values(Rules.items()) ++ Map.values(Rules.potions())

  defp skills,
    do:
      Enum.uniq(
        Enum.flat_map(Rules.sets(), fn set -> Enum.map(Rules.lessons(set.name), & &1.skill) end)
      )

  defp monster_spells,
    do:
      Rules.monsters()
      |> Map.values()
      |> Enum.flat_map(& &1.spells)
      |> Enum.map(&Rules.monster_spell(&1).shown)
      |> Enum.uniq()

  # What an item's emoji is chosen by: a weapon's type, anything else's slot.
  defp kind(%{slot: :weapon, type: type}), do: "weapon #{type}"
  defp kind(item), do: item.slot

  test "every item, skill and monster spell has an emoji" do
    for item <- items(), do: assert(is_binary(Names.item_emoji(item)), item.name)
    for name <- skills() ++ monster_spells(), do: assert(is_binary(Names.skill_emoji(name)), name)
  end

  test "no two things the game names share an emoji, but the heals' 💚" do
    worn =
      Enum.map(items(), &{Names.item_emoji(&1), "item: #{kind(&1)}"}) ++
        Enum.map(skills() ++ monster_spells(), &{Names.skill_emoji(&1), "skill: #{&1}"}) ++
        Enum.map(@conditions, &{Constants.aura(&1).emoji, "condition: #{&1}"}) ++
        Enum.map(Constants.races(), &{&1.emoji, "race: #{&1.label}"})

    heals = for {name, %{kind: :heal}} <- Rules.skills(), do: "skill: #{name}"

    # Every item of one kind shares its kind's emoji (every sword is 🗡️), so a kind counts once.
    for {emoji, wearers} <- Enum.group_by(worn, &elem(&1, 0), &elem(&1, 1)),
        wearers = Enum.uniq(wearers),
        length(wearers) > 1,
        do:
          assert(
            Enum.all?(wearers, &(&1 in heals)),
            "#{emoji} is worn by #{Enum.join(wearers, ", ")}"
          )

    for name <- heals, do: assert(Names.skill_emoji(String.trim_leading(name, "skill: ")) == "💚")
  end

  test "an aura's skill wears the emoji its effect shows in Buffs" do
    for name <- ["Defense Aura", "Attack Aura", "Shield", "Soul Shield", "Relax"],
        do: assert(Names.skill_emoji(name) == Constants.skill_aura(name).emoji)

    assert Names.skill_emoji("Defense Aura") == "🧱"
    refute Names.skill_emoji("Power Shot") == Names.item_emoji("Forest Bow")
  end

  test "a sentence names an item or a skill in its class, led by its emoji" do
    assert Names.item("Long Sword") == ~s(<span class="item">🗡️ Long Sword</span>)
    assert Names.item(Rules.item("Round Shield")) == ~s(<span class="item">🛡️ Round Shield</span>)

    assert Names.item("Lesser Healing Potion") ==
             ~s(<span class="item">🧪 Lesser Healing Potion</span>)

    assert Names.skill("Wind Strike") == ~s(<span class="skill">🌪️ Wind Strike</span>)
    assert Names.skill("Wind Strike", 2) == ~s(<span class="skill">🌪️ Wind Strike 2</span>)
    assert Names.skill("HP Drain") == ~s(<span class="skill">🦟 HP Drain</span>)
  end
end
