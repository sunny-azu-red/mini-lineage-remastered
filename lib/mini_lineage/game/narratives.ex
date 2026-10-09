defmodule MiniLineage.Game.Narratives do
  @moduledoc "Narrative templates. Each list is drawn from by index, so ORDER is load-bearing."

  # Joined mid-sentence ("You chose the Orc Fighter, and ..."), so none of them starts a new one.
  @welcome [
    "{their} destiny awaits in the dark!",
    "the fires of fate burn for {object}...",
    "a hero rises from the ashes now!",
    "the world of Aden calls to {object}...",
    "blood and iron define {their} soul!",
    "steel and magic are {their} allies!",
    "ancient echoes follow {their} feet!",
    "{them} take a bold step toward {their} destiny!",
    "{their} spirit shines in the dark..."
  ]

  # They/them takes the same verb forms as you, so only the pronouns move between the two voices.
  @voices %{
    true => %{
      they: "You",
      them: "you",
      object: "you",
      their: "your"
    },
    false => %{
      they: "They",
      them: "they",
      object: "them",
      their: "their"
    }
  }

  @began ~s({they} chose the {raceEmoji} {className}, and {welcome} {they} set out from {townEmoji} {town} as {build} {definition} of {age} seasons.)

  def welcome, do: @welcome
  def began, do: @began

  @doc "The pronoun set a template is filled from: the reader's own, or somebody else's."
  def voice(mine?), do: Map.fetch!(@voices, mine?)
end
