defmodule MiniLineage.Game.Narrative do
  @moduledoc """
  Lines told with their pronouns open (`{they}`, `{their}`…), closed for whoever reads them: "you"
  for the run itself, "they" for anybody else.
  """
  alias MiniLineage.Game.{Format, Narratives, Rules}

  @doc "Who a run set out as, and from where."
  def build_began(race, class_name) do
    town = Rules.town(Rules.hometown(race.id))

    Format.fill_template(Narratives.began(), %{
      "raceEmoji" => race.emoji,
      "className" => class_name,
      "townEmoji" => town.emoji,
      "town" => town.name
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

  @doc """
  Rules §20: the fight log, each line open-voiced: the meeting, the auras and heals before the pull
  (`before`, as `{done, hp}`), then one line a round.
  """
  def build_fight_log(foe, ground, log, %{max_hp: max_hp, bow?: bow?}, before) do
    met =
      Format.fill_template(
        if(foe.aggressive?, do: Narratives.noticed(), else: Narratives.met()),
        %{
          "article" => article(foe.name),
          "Article" => String.capitalize(article(foe.name)),
          "monster" => foe.name,
          "level" => foe.level,
          "ground" => ground.name
        }
      )

    rounds =
      log
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
      |> Enum.sort()
      |> Enum.map(fn
        {round, events} ->
          {standing, events} = Enum.split_with(events, &match?({:standing, _, _}, &1))
          parts = events |> merge_swings() |> Enum.map(&event(&1, foe, bow?))

          "Round #{round}: " <> join(parts) <> " " <> standing(standing, foe, max_hp) <> "."
      end)

    [met | before(before, max_hp)] ++ rounds
  end

  # Rules §20: the auras raised and heals cast before the pull, as one line.
  defp before({[], _hp}, _max_hp), do: []

  defp before({done, hp}, max_hp) do
    parts = Enum.map(done, &event(&1, nil))

    [
      "Before the fight: " <>
        join(parts) <> " " <> fill(:mended, %{"hp" => hp, "max" => max_hp}) <> "."
    ]
  end

  defp standing([{:standing, hp, left}], foe, max_hp),
    do:
      fill(:standing, %{
        "monster" => foe.name,
        "foe" => left,
        "foe_max" => foe.hp,
        "hp" => hp,
        "max" => max_hp
      })

  defp event(:readying, _foe, true), do: fill(:draw, %{})
  defp event(:readying, _foe, false), do: fill(:ready, %{})
  defp event(:casting, _foe, _bow?), do: fill(:casting, %{})
  defp event(other, foe, _bow?), do: event(other, foe)

  defp event({:blow, amount, true}, _foe), do: fill(:critical, %{"amount" => amount})

  defp event({:blows, amounts}, _foe) do
    amounts = Enum.map(amounts, &~s(<span class="attack">#{&1}</span>))
    fill(:blow, %{"amount" => join_and(amounts)})
  end

  defp event(:miss, _foe), do: fill(:miss, %{})
  defp event(:closing, foe), do: fill(:closing, %{"monster" => foe.name})
  defp event({:begin, skill}, _foe), do: fill(:begin, %{"skill" => skill})

  defp event({:foe_begin, spell}, foe),
    do: fill(:foe_begin, %{"monster" => foe.name, "skill" => spell})

  defp event(:waiting, foe), do: fill(:waiting, %{"monster" => foe.name})
  defp event(:advancing, foe), do: fill(:advancing, %{"monster" => foe.name})
  defp event({:skill, skill, 0}, _foe), do: fill(:skill_failed, %{"skill" => skill})

  defp event({:skill, skill, amount}, _foe),
    do: fill(:skill, %{"skill" => skill, "amount" => amount})

  defp event({:cast, skill, 0, _}, _foe), do: fill(:ignite, %{"skill" => skill})

  defp event({:cast, skill, amount, critical?}, _foe),
    do:
      fill(if(critical?, do: :magic_critical, else: :cast), %{
        "skill" => skill,
        "amount" => amount
      })

  # §19: a drain says what it mends, as a heal does, unless the caster was already whole.
  defp event({:drain, skill, amount, critical?, 0}, foe),
    do: event({:cast, skill, amount, critical?}, foe)

  defp event({:drain, skill, amount, critical?, healed}, _foe),
    do:
      fill(if(critical?, do: :drain_critical, else: :drain), %{
        "skill" => skill,
        "amount" => amount,
        "healed" => healed
      })

  defp event({:burn, amount}, _foe), do: fill(:burn, %{"amount" => amount})
  defp event({:poison, amount}, _foe), do: fill(:poison, %{"amount" => amount})

  defp event({:potion, potion, amount}, _foe),
    do: fill(:potion, %{"potion" => potion, "amount" => amount})

  defp event({:heal, skill, amount}, _foe),
    do: fill(:heal, %{"skill" => skill, "amount" => amount})

  defp event({:aura, skill}, _foe), do: fill(:aura, %{"skill" => skill})
  defp event({:toggle, skill}, _foe), do: fill(:toggle, %{"skill" => skill})

  defp event({:curse, skill, landed?}, foe),
    do:
      fill(if(landed?, do: :curse, else: :curse_failed), %{
        "skill" => skill,
        "monster" => foe.name
      })

  defp event({:foe_blow, amount, critical?, caught}, foe) do
    kind =
      case caught do
        :perfect -> :foe_perfect
        :caught -> :foe_caught
        nil -> if(critical?, do: :foe_critical, else: :foe_blow)
      end

    fill(kind, %{"monster" => foe.name, "amount" => amount})
  end

  defp event(:foe_miss, foe), do: fill(:foe_miss, %{"monster" => foe.name})

  defp event({:foe_cast, spell, amount}, foe),
    do: fill(:foe_cast, %{"monster" => foe.name, "skill" => spell, "amount" => amount})

  defp event({:foe_drain, spell, amount, 0}, foe), do: event({:foe_cast, spell, amount}, foe)

  defp event({:foe_drain, spell, amount, healed}, foe),
    do:
      fill(:foe_drain, %{
        "monster" => foe.name,
        "skill" => spell,
        "amount" => amount,
        "healed" => healed
      })

  defp event({:swings, swings}, _foe),
    do: fill(:swings, %{"times" => times(swings), "outcomes" => outcomes(swings)})

  defp event({:foe_swings, swings}, foe),
    do:
      fill(:foe_swings, %{
        "monster" => foe.name,
        "times" => times(swings),
        "outcomes" => outcomes(swings)
      })

  defp fill(kind, data), do: Format.fill_template(Narratives.log(kind), data)

  # A side's swings in one round read as one clause: "you hit for 10 and 9" when every one landed
  # plainly, else each in order, "you swing twice for a critical hit of 65 and a miss".
  defp merge_swings(events) do
    events
    |> Enum.chunk_by(&swinger/1)
    |> Enum.flat_map(fn [first | _] = chunk -> merged(swinger(first), chunk) end)
  end

  defp swinger({:blow, _, _}), do: :you
  defp swinger(:miss), do: :you
  defp swinger({:foe_blow, _, _, _}), do: :foe
  defp swinger(:foe_miss), do: :foe
  defp swinger(_other), do: nil

  defp merged(nil, events), do: events

  defp merged(:you, swings) do
    cond do
      Enum.all?(swings, &match?({:blow, _, false}, &1)) ->
        [{:blows, Enum.map(swings, &elem(&1, 1))}]

      match?([_], swings) ->
        swings

      true ->
        [{:swings, swings}]
    end
  end

  defp merged(:foe, [_] = one), do: one
  defp merged(:foe, swings), do: [{:foe_swings, swings}]

  defp times([_, _]), do: "twice"
  defp times(swings), do: "#{length(swings)} times"

  defp outcomes(swings), do: swings |> Enum.map(&outcome/1) |> join_and()

  defp outcome({:blow, amount, false}), do: fill(:swing_hit, %{"amount" => amount})
  defp outcome({:blow, amount, true}), do: fill(:swing_critical, %{"amount" => amount})
  defp outcome(:miss), do: fill(:swing_miss, %{})
  defp outcome(:foe_miss), do: fill(:swing_miss, %{})
  defp outcome({:foe_blow, _, _, :perfect}), do: fill(:foe_swing_perfect, %{})

  defp outcome({:foe_blow, amount, _, :caught}),
    do: fill(:foe_swing_caught, %{"amount" => amount})

  defp outcome({:foe_blow, amount, true, nil}),
    do: fill(:foe_swing_critical, %{"amount" => amount})

  defp outcome({:foe_blow, amount, false, nil}), do: fill(:foe_swing_hit, %{"amount" => amount})

  defp join_and([only]), do: only
  defp join_and(parts), do: Enum.join(Enum.drop(parts, -1), ", ") <> " and " <> List.last(parts)

  # "you hit for 9, the Wolf misses, and you hit for 8"
  defp join([only]), do: only
  defp join(parts), do: Enum.join(Enum.drop(parts, -1), ", ") <> ", and " <> List.last(parts)

  defp article(name), do: if(String.first(name) in ~w(A E I O U), do: "an", else: "a")

  @doc "What a skill needs in hand, as a sentence names it."
  def weapon_for(skill), do: needs(skill)

  defp needs("Power Strike"), do: weapon("sword")
  defp needs("Power Shot"), do: weapon("bow")
  defp needs("Mortal Blow"), do: weapon("dagger")
  defp needs("Iron Punch"), do: weapon("fists")

  @doc "A weapon type, as a sentence names one."
  def weapon("fists"), do: "a fist weapon"
  def weapon(type), do: "#{article(String.upcase(type))} #{type}"

  def voiced(line, mine?), do: Format.fill_template(line, pronouns(mine?))

  @doc "A line as its owner's alert."
  def alert(line), do: voiced(line, true)

  defp pronouns(mine?),
    do: mine? |> Narratives.voice() |> Map.new(fn {part, word} -> {to_string(part), word} end)
end
