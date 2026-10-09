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
        "The most adaptable of all lineages. A Human Fighter is strong and hardy without leaning too far either way, and a Human Mystic pairs a sharp mind with a steady spirit."
    },
    %{
      id: 1,
      label: "Orc",
      hometown:
        "The Orc Village stands on a barren plateau of the north, among the tribes who raised it.",
      plural: "Orcs",
      emoji: "🧟",
      backstory:
        "Towering warriors of immense physical resilience. No Fighter is born with a hardier constitution than an Orc's, nor any Mystic with a stronger spirit, so their wounds close faster than anyone's. Their hands are the clumsiest of the four."
    },
    %{
      id: 2,
      label: "Elf",
      hometown: "Built among the roots of the Mother Tree, deep in the Elven Forest.",
      plural: "Elves",
      emoji: "🧝",
      backstory:
        "Swift and favored by nature. An Elven Fighter is the most dexterous of all, striking true and often, and an Elven Mystic thinks faster on their feet than any other. Their frames are lighter than a Human's or an Orc's."
    },
    %{
      id: 3,
      label: "Dark Elf",
      hometown: "Hidden in the shadowed forests where the Dark Elves keep their own counsel.",
      plural: "Dark Elves",
      emoji: "🧛",
      backstory:
        "Lethal stalkers of the night. A Dark Fighter hits harder than any other, and a Dark Mystic's intellect has no equal, which makes their magic the most dangerous in the realm. Both pay for it with the frailest constitutions of all."
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
