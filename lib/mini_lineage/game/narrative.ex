defmodule MiniLineage.Game.Narrative do
  @moduledoc """
  Lines told with their pronouns open (`{they}`, `{their}`…), closed for whoever reads them: "you"
  for the run itself, "they" for anybody else.
  """
  alias MiniLineage.Game.{Format, Narratives, Rules}

  @doc "Who a run set out as, and from where. `welcome` still carries its own open pronouns."
  def build_began(race, traits) do
    town = Rules.town(Rules.hometown(race.id))

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

  @doc "Through a Gatekeeper, and what it cost."
  def build_arrived(town, fee) do
    Format.fill_template(Narratives.arrived(), %{
      "townEmoji" => town.emoji,
      "town" => town.name,
      "fee" => Format.number(fee)
    })
  end

  @doc "Rules §20: a kill, with its EXP, SP and whatever Adena it carried."
  def build_slew(monster, ground, exp, sp, adena) do
    Format.fill_template(Narratives.slew(), %{
      "monster" => monster.name,
      "ground" => ground.name,
      "exp" => Format.number(exp),
      "sp" => Format.number(sp),
      "adena" =>
        if(adena > 0,
          do: ~s(, and <span class="adena">#{Format.number(adena)} Adena</span> from its body),
          else: ""
        )
    })
  end

  def build_levelled(level), do: Format.fill_template(Narratives.levelled(), %{"level" => level})

  def build_fell(monster, ground),
    do:
      Format.fill_template(Narratives.fell(), %{
        "monster" => monster.name,
        "ground" => ground.name
      })

  def build_wandered(monster, ground),
    do:
      Format.fill_template(Narratives.wandered(), %{
        "monster" => monster.name,
        "ground" => ground.name
      })

  def voiced(line, mine?), do: Format.fill_template(line, pronouns(mine?))

  @doc "A line as its owner's alert."
  def alert(line), do: voiced(line, true)

  defp pronouns(mine?),
    do: mine? |> Narratives.voice() |> Map.new(fn {part, word} -> {to_string(part), word} end)
end
