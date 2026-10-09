defmodule MiniLineage.Game.Narrative do
  @moduledoc """
  Lines told with their pronouns open (`{they}`, `{their}`…), closed for whoever reads them: "you"
  for the run itself, "they" for anybody else.
  """
  alias MiniLineage.Game.{Format, Narratives, Rules}

  @doc "Who a run set out as, and from where. `welcome` still carries its own open pronouns."
  def build_began(race, traits) do
    town = Rules.town(race.id)

    Format.fill_template(Narratives.began(), %{
      "raceEmoji" => race.emoji,
      "className" => traits.class_name,
      "welcome" => traits.welcome,
      "townEmoji" => town.emoji,
      "town" => town.name,
      "build" => traits.build,
      "definition" => traits.definition,
      "age" => traits.age
    })
  end

  def voiced(nil, _mine?), do: nil
  def voiced(line, mine?), do: Format.fill_template(line, pronouns(mine?))

  @doc "A line as its owner's alert."
  def alert(line), do: voiced(line, true)

  defp pronouns(mine?),
    do: mine? |> Narratives.voice() |> Map.new(fn {part, word} -> {to_string(part), word} end)
end
