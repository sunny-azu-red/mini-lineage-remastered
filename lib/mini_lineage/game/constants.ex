defmodule MiniLineage.Game.Constants do
  @moduledoc """
  The game's prose and presentation: the races' lore and perks, the towns, the auras, and how a new
  character is described. Every number a rule decides lives in `Rules`, never here.
  """

  @races [
    %{
      id: 0,
      label: "Human",
      perk:
        "Humans have no racial perk, because their strength is having the most class choices.",
      plural: "Humans",
      emoji: "🧙",
      backstory:
        "Humans in Lineage II are similar to Humans in the modern world. Humans currently have the greatest dominion in the world and the largest population."
    },
    %{
      id: 1,
      label: "Orc",
      perk: "Orcs shrug off sleep, root and poison better than any other race.",
      plural: "Orcs",
      emoji: "🧟",
      backstory:
        "The Orc race is the race of fire. Among all races, Orcs possess the greatest physical abilities. After the destruction of the giants, they were able to expel the Elven powers and attain the most powerful position on the continent. However, they were defeated by the Elf-Human alliance some time later, and are currently living in an arctic area of the northern region of the continent."
    },
    %{
      id: 2,
      label: "Elf",
      perk: "Elves rest half again as fast in their home village, beneath the Mother Tree.",
      plural: "Elves",
      emoji: "🧝",
      backstory:
        "The race of Elves worships the goddess of water and loves nature and aquatic life. The Elves have slim and nimble bodies, long ears and beautiful features. During the era of giants, among all creatures they held the highest position. However, when the giants were destroyed, the power and influence of the Elves was also diminished. Now they only inhabit part of the forest on the main continent."
    },
    %{
      id: 3,
      label: "Dark Elf",
      perk: "Dark Elves see better at night, when everyone else strains to land a blow.",
      plural: "Dark Elves",
      emoji: "🧛",
      backstory:
        "Dark Elves were once part of the Elven tribes, but were banished after they learned black magic in order to obtain the power to fight Humans. They lost the battle, but continued to study the dark arts. Dark Elves have similar features to their Elven brethren, but are taller, have blue-gray skin, and silver hair. They follow Shilen, the goddess of Death."
    }
  ]

  # Rules §24: what each village's traders say as a page of theirs opens, from their own greetings;
  # the Magic Trader's two keepers speak in one line.
  @trader_lines %{
    {"talking-island", :weapon} =>
      "Lector lays out the weapons your path can use, and warns that the most expensive is not always the best, since a weapon serves only the one it suits.",
    {"talking-island", :armour} =>
      "Jackson waves you in to look around, sure that it always pays to buy the best armour you can, since every battle grows easier for it.",
    {"talking-island", :magic} =>
      "Silvia minds the jewellery for an aunt and asks you to choose quickly, while Katerina wishes you the luck of the goddess and offers potions that are not rare but serve well when they are used wisely.",
    {"elven-village", :weapon} =>
      "Unoren trades in the small tools that matter most on the battlefield, from sharp bronze daggers to the finest swords, and bids you have a look.",
    {"elven-village", :armour} =>
      "Ariel sells everything that protects a life and a reputation, from gorgeous armour to a strong shield, and none of it a mere accessory.",
    {"elven-village", :magic} =>
      "Creamees asks whether the fragrance of the herbs is not nice while young Herbiel compounds a new medicine, sweet potions that revive the tired body, and both bid you take your time.",
    {"dark-elf-village", :weapon} =>
      "Iria deals in no weapons made by clumsy Humans, and tells you to buy quickly or get out of sight.",
    {"dark-elf-village", :armour} =>
      "Payne bids you welcome to a shop full of fine wares, each one waiting for the touch of a brave and dashing hero.",
    {"dark-elf-village", :magic} =>
      "Minaless blesses you in the name of the goddess of darkness and swears the finest jewellery is gathered here for the followers of Shilen, while Vollodos cries out that every potion is fresh and a steal.",
    {"orc-village", :weapon} =>
      "Jakal greets you for the glory of the everlasting flame, and swears there is nothing Jakal cannot find for a child of the flame.",
    {"orc-village", :armour} =>
      "Kunai greets you for the glory of the everlasting flame, and vouches for wares the Dwarves made, who are hated but make them well.",
    {"orc-village", :magic} =>
      "Uska and Papuma greet you for the glory of the everlasting flame, Uska laughing that an Orc should not waste even a few seconds choosing, and Papuma reminding you to train hard for the glory of your people."
  }

  # Rules §14's open towns as a reader finds them, by slug. One not yet open is never stood in.
  @towns %{
    "talking-island" =>
      "A quiet village on Talking Island, off the mainland's coast, where every Human first takes up a blade or a staff.",
    "elven-village" => "Built among the roots of the Mother Tree, deep in the Elven Forest.",
    "dark-elf-village" =>
      "Hidden in the shadowed forests where the Dark Elves keep their own counsel.",
    "orc-village" =>
      "The Orc Village stands on a barren plateau of the north, among the tribes who raised it.",
    "gludio" =>
      "A walled town in the south of the mainland, where the roads from every starting village meet.",
    "dion" =>
      "Wheat fields roll out from Dion's walls toward the castle on the hill, and the road east runs on to Giran."
  }

  # Derived, never stored: a started character always rests (rules §11, there being no combat), and
  # regenerates while a bar is short, at the rates `Player` fills in. Night and the perks are what
  # the time and the place put on it (rules §15 and §16), carrying the modifiers `Rules` gives them.
  @auras %{
    combat: %{
      id: "combat",
      type: :aura,
      emoji: "⚔️",
      label: "In Combat",
      about:
        "Out on the hunting ground the body does not rest, and it begins to again only a few seconds after you are back in town."
    },
    resting: %{
      id: "resting",
      type: :aura,
      emoji: "💤",
      label: "Resting",
      about: "Between fights, the body rests and mends every three seconds."
    },
    night: %{
      id: "night",
      type: :debuff,
      emoji: "🌙",
      label: "Night",
      about: "The sun is down, and every blow strains to find its mark."
    },
    shadow_sense: %{
      id: "shadow_sense",
      type: :buff,
      emoji: "👁️",
      label: "Shadow Sense",
      about: "Dark Elven eyes see through the night as if it were day."
    },
    mother_tree: %{
      id: "mother_tree",
      type: :buff,
      emoji: "🌳",
      label: "Blessing of the Mother Tree",
      about: "Resting beneath the Mother Tree mends half again as fast."
    },
    regenerating: %{
      id: "regenerating",
      type: :aura,
      emoji: "🌿",
      label: "Regenerating",
      about: "Health or mana is short of full, and rest is filling it back up."
    }
  }

  # Rules §19 and §11: what a character's own skills put on it, keyed by the skill.
  @skill_auras %{
    "Defense Aura" => %{
      id: "defense_aura",
      type: :buff,
      emoji: "🛡️",
      label: "Defense Aura",
      about: "An aura raised in the field turns blows aside."
    },
    "Attack Aura" => %{
      id: "attack_aura",
      type: :buff,
      emoji: "💪",
      label: "Attack Aura",
      about: "An aura raised in the field drives every blow harder."
    },
    "Shield" => %{
      id: "shield",
      type: :buff,
      emoji: "🔰",
      label: "Shield",
      about: "A ward cast on oneself hardens the skin against blows."
    },
    "Soul Shield" => %{
      id: "soul_shield",
      type: :buff,
      emoji: "💠",
      label: "Soul Shield",
      about: "The spirits called to stand guard turn blows aside."
    },
    "Relax" => %{
      id: "relax",
      type: :buff,
      emoji: "🧘",
      label: "Relax",
      about: "Sitting still and breathing slow mends wounds faster, at a cost in mana."
    }
  }

  @character %{
    name_min_length: 1,
    name_max_length: 20
  }

  def races, do: @races

  def race(id),
    do: Enum.find(@races, &(&1.id == id)) || raise(ArgumentError, "no race #{inspect(id)}")

  def town_description(slug), do: Map.fetch!(@towns, slug)
  def trader_line(village, role), do: Map.fetch!(@trader_lines, {village, role})
  def aura(key), do: Map.fetch!(@auras, key)
  def skill_aura(skill), do: Map.fetch!(@skill_auras, skill)
  def character, do: @character
end
