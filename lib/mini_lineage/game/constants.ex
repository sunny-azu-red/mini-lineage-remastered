defmodule MiniLineage.Game.Constants do
  @moduledoc """
  The game's prose and presentation: the races' lore, the two auras, and how a new character is
  described. Every number a rule decides lives in `Rules`, never here.
  """

  @races [
    %{
      id: 0,
      label: "Human",
      hometown:
        "A quiet village on Talking Island, off the mainland's coast, where every Human first takes up a blade or a staff.",
      plural: "Humans",
      emoji: "🧙",
      backstory:
        "Humans in Lineage II are similar to Humans in the modern world. Humans currently have the greatest dominion in the world and the largest population."
    },
    %{
      id: 1,
      label: "Orc",
      hometown:
        "The Orc Village stands on a barren plateau of the north, among the tribes who raised it.",
      plural: "Orcs",
      emoji: "🧟",
      backstory:
        "The Orc race is the race of fire. Among all races, Orcs possess the greatest physical abilities. After the destruction of the giants, they were able to expel the Elven powers and attain the most powerful position on the continent. However, they were defeated by the Elf-Human alliance some time later, and are currently living in an arctic area of the northern region of the continent."
    },
    %{
      id: 2,
      label: "Elf",
      hometown: "Built among the roots of the Mother Tree, deep in the Elven Forest.",
      plural: "Elves",
      emoji: "🧝",
      backstory:
        "The race of Elves worships the goddess of water and loves nature and aquatic life. The Elves have slim and nimble bodies, long ears and beautiful features. During the era of giants, among all creatures they held the highest position. However, when the giants were destroyed, the power and influence of the Elves was also diminished. Now they only inhabit part of the forest on the main continent."
    },
    %{
      id: 3,
      label: "Dark Elf",
      hometown: "Hidden in the shadowed forests where the Dark Elves keep their own counsel.",
      plural: "Dark Elves",
      emoji: "🧛",
      backstory:
        "Dark Elves were once part of the Elven tribes, but were banished after they learned black magic in order to obtain the power to fight Humans. They lost the battle, but continued to study the dark arts. Dark Elves have similar features to their Elven brethren, but are taller, have blue-gray skin, and silver hair. They follow Shilen, the goddess of Death."
    }
  ]

  # Derived, never stored: a started character always rests (rules §11, there being no combat), and
  # regenerates while a bar is short, at the rates `Player` fills in.
  @auras %{
    resting: %{id: "resting", type: :aura, emoji: "💤", label: "Resting"},
    regenerating: %{id: "regenerating", type: :aura, emoji: "🌿", label: "Regenerating"}
  }

  @character %{
    min_age: 9,
    max_age: 69,
    age_thresholds: %{
      youth: 23,
      adult: 54,
      labels: %{youth: "youth", adult: "adult", elder: "elder"}
    },
    name_min_length: 1,
    name_max_length: 20,
    builds: ["a hardy", "a wiry", "a sturdy", "a fit", "a rugged", "a robust", "a solid"]
  }

  def races, do: @races
  def race(id), do: Enum.at(@races, id) || hd(@races)
  def aura(key), do: Map.fetch!(@auras, key)
  def character, do: @character
end
