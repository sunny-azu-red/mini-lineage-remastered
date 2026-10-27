defmodule MiniLineage.Game.Narrative do
  @moduledoc """
  Lines told with their pronouns open (`{they}`, `{their}`…), closed for whoever reads them: "you"
  for the run itself, "they" for anybody else.
  """
  alias MiniLineage.Game.{Format, Hunt, Names, Narratives, Rules}

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

  @doc "Through the Gatekeeper of the town left, and what it cost."
  def build_arrived(gatekeeper, town, fee) do
    Format.fill_template(Narratives.arrived(), %{
      "gatekeeper" => gatekeeper,
      "townEmoji" => town.emoji,
      "town" => town.name,
      "fee" => Format.adena(fee)
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
          do: ", and #{Format.adena(adena)} from its body",
          else: ""
        )
    })
  end

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

  @doc "Rules §17: the ground outside a village, as its page opens."
  def ground_intro(ground, town),
    do:
      Format.fill_template(Narratives.ground_intro(ground.slug), %{
        "ground" => ground.name,
        "townEmoji" => town.emoji,
        "town" => town.name
      })

  @doc """
  Rules §20: the fight log as entries, each a head, where both stand after it (`standing`, at the
  right of the head), its line, open-voiced, and the `kind` its row is washed as (`nil` for none):
  the meeting, the auras and heals before the pull (`before`, as `{done, hp}`), then one entry a
  round, washed for a critical hit on either side, else for HP either side mended. A round is told
  one sentence per side, in the order they acted, every attack naming how it was made and the
  weapon it was made with, and every item and skill named as `Names` names it.
  """
  def build_fight_log(foe, ground, log, %{max_hp: max_hp, hp: hp} = you, before) do
    you = Map.take(you, [:weapon, :shield])

    met = %{
      head: if(foe.aggressive?, do: "Ambush", else: "Encounter"),
      kind: if(foe.aggressive?, do: "ambush", else: "encounter"),
      standing: standing(foe, foe.hp, hp, max_hp),
      line:
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
    }

    rounds =
      log
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
      |> Enum.sort()
      |> news()
      |> Enum.map(fn
        {round, events} ->
          {[{:standing, health, left}], events} =
            Enum.split_with(events, &match?({:standing, _, _}, &1))

          {casting, events} = Enum.split_with(events, &(&1 == :casting))

          sentences =
            events
            |> merge_swings()
            |> Enum.chunk_by(&side/1)
            |> Enum.map(fn chunk -> chunk |> Enum.map(&event(&1, foe, you)) |> join() end)

          %{
            head: round_label(round),
            kind: kind(events),
            standing: standing(foe, left, health, max_hp),
            line: tell(still_casting(casting), sentences)
          }
      end)

    [met | before(before, foe, max_hp)] ++ rounds
  end

  # §20: a cast or a run is told once, as it begins, so a round left with nothing new is not
  # written; no HP moves without an event of its own, so its standing is the last one written.
  # A cast still going on is told only beside something else, to say why the character did nothing.
  defp news(rounds) do
    rounds
    |> Enum.map_reduce([], fn {round, events}, before ->
      {{round, Enum.reject(events, &going_on?(&1, before))}, events}
    end)
    |> elem(0)
    |> Enum.reject(fn {_round, events} -> Enum.all?(events, &quiet?/1) end)
  end

  defp quiet?(event), do: event == :casting or match?({:standing, _, _}, event)

  # A critical outranks a mend, which a draining Mystic does most rounds.
  defp kind(events) do
    cond do
      Enum.any?(events, &critical?/1) -> "critical"
      Enum.any?(events, &mended?/1) -> "heal"
      true -> nil
    end
  end

  # Exactly what `event/3` tells as a critical: a blocked blow is told as the block.
  defp critical?({:blow, _, true, _}), do: true
  defp critical?({:cast, _, _, true, _}), do: true
  defp critical?({:drain, _, _, true, _, _, _}), do: true
  defp critical?({:foe_blow, _, true, nil, _}), do: true
  defp critical?(_event), do: false

  defp mended?({:heal, _, amount, _}), do: amount > 0
  defp mended?({:potion, _, amount, _}), do: amount > 0
  defp mended?({:drain, _, _, _, healed, _, _}), do: healed > 0
  defp mended?({:foe_drain, _, _, healed, _, _}), do: healed > 0
  defp mended?(_event), do: false

  defp still_casting([]), do: ""
  defp still_casting([:casting]), do: fill(:casting, %{}) <> " "

  # "As you cast," opens the round's first sentence, whichever side's it is.
  defp tell(lead, [first | rest]),
    do: Enum.map_join([sentence(lead <> first) | Enum.map(rest, &sentence/1)], " ", &(&1 <> "."))

  defp going_on?(:waiting, _before), do: true
  defp going_on?(event, before) when event in [:closing, :advancing], do: event in before
  defp going_on?(_event, _before), do: false

  # §20: each round says when it starts on the fight's clock, in the tenths a skill row's cast and
  # reuse are written in, so a reuse can be read off the log.
  defp round_label(round) do
    seconds = Format.tenths(round(Hunt.round_starts_ms(round) / 100))

    ~s(Round #{round} <span class="delimiter">&bull;</span> #{seconds}<span class="unit">s</span>)
  end

  # Rules §20: the auras raised and heals cast before the pull, as one entry, the same heal cast
  # again told once with all it mended.
  defp before({[], _hp}, _foe, _max_hp), do: []

  defp before({done, hp}, foe, max_hp) do
    parts =
      done
      |> Enum.chunk_by(fn
        {:heal, skill, _, _} -> {:heal, skill}
        other -> other
      end)
      |> Enum.map(&again/1)
      |> Enum.map(&event(&1, nil, %{}))

    [
      %{
        head: "Before the fight",
        kind: if(Enum.any?(done, &mended?/1), do: "heal"),
        standing: standing(foe, foe.hp, hp, max_hp),
        line: sentence(join(parts)) <> "."
      }
    ]
  end

  defp again([{:heal, skill, _, _} | _] = heals),
    do:
      {:heals, skill, length(heals), Enum.sum_by(heals, &elem(&1, 2)),
       Enum.sum_by(heals, &elem(&1, 3))}

  defp again([one]), do: one

  defp standing(foe, left, hp, max_hp),
    do:
      Format.fill_template(Narratives.standing(), %{
        "foe" => percent(left, foe.hp),
        "hp" => percent(hp, max_hp)
      })

  # Floored, as the HP bar's percent is, but a side still standing never reads 0%.
  defp percent(0, _whole), do: Format.percent(0)
  defp percent(part, whole), do: Format.percent(max(div(part * 100, whole), 1))

  # A sentence's first word is capitalised, its pronoun still open.
  defp sentence("{them}" <> rest), do: "{they}" <> rest
  defp sentence("{their}" <> rest), do: "{Their}" <> rest
  defp sentence(<<first::utf8, rest::binary>>), do: String.upcase(<<first::utf8>>) <> rest

  # Which sentence of its round an event is told in.
  @foe_events [:foe_blow, :foe_blows, :foe_misses, :foe_swings, :foe_begin, :foe_cast, :foe_drain]
  defp side(:foe_miss), do: :foe
  defp side(:closing), do: :foe
  defp side(event) when is_tuple(event) and elem(event, 0) in @foe_events, do: :foe
  defp side(_event), do: :you

  defp event(:readying, _foe, %{weapon: %{type: "bow"} = bow}),
    do: fill(:draw, %{"weapon" => bow})

  defp event(:readying, _foe, _you), do: fill(:ready, %{})

  defp event({:blows, hits}, _foe, you),
    do: fill(:blow, Map.put(amounts(hits, "attack"), "motion", yours(you, hits)))

  defp event({:blow, amount, true, over} = blow, _foe, you),
    do: fill(:critical, Map.put(hit(amount, over), "motion", yours(you, [blow])))

  defp event(:miss, _foe, you), do: fill(:miss, %{"motion" => yours(you, [:miss])})

  defp event({:misses, swings}, _foe, you),
    do: fill(:misses, %{"motion" => yours(you, swings), "every" => every(swings)})

  defp event({:swings, swings}, _foe, you),
    do: fill(:swings, %{"motion" => yours(you, swings), "outcomes" => outcomes(swings, you)})

  defp event({:foe_blows, hits}, foe, _you),
    do: fill(:foe_blow, Map.merge(amounts(hits, "hp"), foe_data(foe, hits)))

  defp event({:foe_blow, amount, critical?, caught, over} = blow, foe, you) do
    kind =
      case caught do
        :perfect -> :foe_perfect
        :caught -> :foe_caught
        nil -> if(critical?, do: :foe_critical, else: :foe_blow)
      end

    fill(kind, hit(amount, over) |> Map.merge(foe_data(foe, [blow])) |> shielded(you))
  end

  defp event(:foe_miss, foe, _you), do: fill(:foe_miss, foe_data(foe, [:foe_miss]))

  defp event({:foe_misses, swings}, foe, _you),
    do: fill(:foe_misses, Map.put(foe_data(foe, swings), "every", every(swings)))

  defp event({:foe_swings, swings}, foe, you),
    do: fill(:foe_swings, Map.put(foe_data(foe, swings), "outcomes", outcomes(swings, you)))

  defp event(other, foe, _you), do: event(other, foe)

  defp event({:no_mp, skill}, _foe), do: fill(:no_mp, %{"skill" => skill})
  defp event(:closing, foe), do: fill(:closing, %{"monster" => foe.name})
  defp event({:begin, skill}, _foe), do: fill(:begin, %{"skill" => skill})

  defp event({:foe_begin, spell}, foe),
    do: fill(:foe_begin, %{"monster" => foe.name, "skill" => shown(spell)})

  defp event(:advancing, foe), do: fill(:advancing, %{"monster" => foe.name})
  defp event({:skill, skill, 0, _}, _foe), do: fill(:skill_missed, %{"skill" => skill})

  defp event({:skill, skill, amount, over}, _foe),
    do: fill(:skill, Map.put(hit(amount, over), "skill", skill))

  defp event({:ignite, skill}, foe),
    do: fill(:ignite, %{"skill" => skill, "monster" => foe.name})

  defp event({:cast, skill, amount, critical?, over}, _foe),
    do:
      fill(
        if(critical?, do: :magic_critical, else: :cast),
        Map.put(hit(amount, over), "skill", skill)
      )

  # §19: a drain says what it mends, as a heal does, its share past full as overheal, so a caster
  # already whole reads it wasted; only a drain worth nothing at all reads as a plain cast.
  defp event({:drain, skill, amount, critical?, 0, over, 0}, foe),
    do: event({:cast, skill, amount, critical?, over}, foe)

  defp event({:drain, skill, amount, critical?, healed, over, overheal}, _foe),
    do:
      fill(
        if(critical?, do: :drain_critical, else: :drain),
        hit(amount, over)
        |> Map.merge(mend(healed, overheal, "healed"))
        |> Map.put("skill", skill)
      )

  defp event({:burn, skill, amount, over}, foe),
    do: fill(:burn, Map.merge(hit(amount, over), %{"skill" => skill, "monster" => foe.name}))

  defp event({:poison, skill, amount}, foe),
    do: fill(:poison, %{"skill" => skill, "amount" => amount, "monster" => foe.name})

  defp event({:potion, potion, amount, over}, _foe),
    do: fill(:potion, Map.put(mend(amount, over, "amount"), "potion", potion))

  defp event({:heal, skill, amount, over}, foe), do: event({:heals, skill, 1, amount, over}, foe)

  defp event({:heals, skill, count, amount, over}, _foe),
    do:
      fill(
        :heal,
        Map.merge(mend(amount, over, "amount"), %{"skill" => skill, "times" => times(count)})
      )

  defp event({:aura, skill}, _foe), do: fill(:aura, %{"skill" => skill})
  defp event({:toggle, skill}, _foe), do: fill(:toggle, %{"skill" => skill})

  defp event({:curse, skill, landed?}, foe),
    do:
      fill(if(landed?, do: :curse, else: :curse_failed), %{
        "skill" => skill,
        "monster" => foe.name
      })

  defp event({:foe_cast, spell, amount, over}, foe),
    do:
      fill(
        :foe_cast,
        Map.merge(hit(amount, over), %{"monster" => foe.name, "skill" => shown(spell)})
      )

  defp event({:foe_drain, spell, amount, 0, over, 0}, foe),
    do: event({:foe_cast, spell, amount, over}, foe)

  defp event({:foe_drain, spell, amount, healed, over, overheal}, foe),
    do:
      fill(
        :foe_drain,
        hit(amount, over)
        |> Map.merge(mend(healed, overheal, "healed"))
        |> Map.merge(%{"monster" => foe.name, "skill" => shown(spell)})
      )

  # §19: the log keeps a monster's spell by its Lineage II name; the player reads what it shows.
  defp shown(spell), do: Rules.monster_spell(spell).shown

  # Rules §20: how the character attacked, with what and how many times: a bow shoots, fists
  # punch, any other weapon swings, and bare hands punch with nothing to name.
  defp yours(you, swings) do
    count = times(length(swings))

    case you[:weapon] do
      nil -> "punch#{count}"
      %{type: "bow"} = bow -> "shoot {their} #{Names.item(bow)}#{count}"
      %{type: "fists"} = fists -> "punch with {their} #{Names.item(fists)}#{count}"
      weapon -> "swing {their} #{Names.item(weapon)}#{count}"
    end
  end

  # The shield a blow landed on, named in the clause that says so.
  defp shielded(data, %{shield: shield}) when shield != nil, do: Map.put(data, "shield", shield)
  defp shielded(data, _you), do: data

  defp foe_data(foe, swings),
    do: %{
      "monster" => foe.name,
      "motion" => "#{if(foe.bow?, do: "shoots", else: "swings")}#{times(length(swings))}"
    }

  defp times(1), do: ""
  defp times(2), do: " twice"
  defp times(count), do: " #{count} times"

  defp every([_, _]), do: "both times"
  defp every(_swings), do: "every time"

  # Every skill and item a line names is named as everywhere else, through `Names`.
  defp fill(kind, data),
    do:
      Format.fill_template(
        Narratives.log(kind),
        %{"overkill" => "", "overheal" => ""}
        |> Map.merge(data)
        |> Map.replace_lazy("skill", &Names.skill/1)
        |> Map.replace_lazy("potion", &Names.item/1)
        |> Map.replace_lazy("weapon", &Names.item/1)
        |> Map.replace_lazy("shield", &Names.item/1)
      )

  # A hit is written at what it was worth, and a mend too, with what went past the last HP or past
  # full in brackets after it: "20 damage (19 overkill)", "50 HP (19 overheal)".
  defp hit(amount, over), do: %{"amount" => amount + over, "overkill" => past(over, "overkill")}

  # "10 and 9 damage": the unit once, after the last, which alone can fell.
  defp amounts(hits, class) do
    {first, [{last, over}]} = Enum.split(hits, -1)
    spans = Enum.map(first, fn {amount, 0} -> ~s(<span class="#{class}">#{amount}</span>) end)

    %{
      "amount" => join_and(spans ++ [~s(<span class="#{class}">#{last + over} damage</span>)]),
      "overkill" => past(over, "overkill")
    }
  end

  defp mend(amount, over, key), do: %{key => amount + over, "overheal" => past(over, "overheal")}

  defp past(0, _word), do: ""
  defp past(over, word), do: " (#{over} #{word})"

  # A side's swings in one round read as one clause: "you swing twice and hit for 10 and 9 damage"
  # when every one landed plainly, "you swing twice and miss both times" when none did, else each
  # in order, "you swing twice: a critical hit of 65 damage and a miss".
  defp merge_swings(events) do
    events
    |> Enum.chunk_by(&swinger/1)
    |> Enum.flat_map(fn [first | _] = chunk -> merged(swinger(first), chunk) end)
  end

  defp swinger({:blow, _, _, _}), do: :you
  defp swinger(:miss), do: :you
  defp swinger({:foe_blow, _, _, _, _}), do: :foe
  defp swinger(:foe_miss), do: :foe
  defp swinger(_other), do: nil

  defp merged(nil, events), do: events

  defp merged(side, swings) do
    cond do
      Enum.all?(swings, &plain?/1) -> [{tag(side, :blows), Enum.map(swings, &worth/1)}]
      match?([_], swings) -> swings
      Enum.all?(swings, &(&1 in [:miss, :foe_miss])) -> [{tag(side, :misses), swings}]
      true -> [{tag(side, :swings), swings}]
    end
  end

  defp plain?({:blow, _, false, _}), do: true
  defp plain?({:foe_blow, _, false, nil, _}), do: true
  defp plain?(_swing), do: false

  defp worth({:blow, amount, false, over}), do: {amount, over}
  defp worth({:foe_blow, amount, false, nil, over}), do: {amount, over}

  defp tag(:you, kind), do: kind
  defp tag(:foe, :blows), do: :foe_blows
  defp tag(:foe, :misses), do: :foe_misses
  defp tag(:foe, :swings), do: :foe_swings

  defp outcomes(swings, you), do: swings |> Enum.map(&outcome(&1, you)) |> join_and()

  defp outcome({:blow, amount, false, over}, _you), do: fill(:swing_hit, hit(amount, over))
  defp outcome({:blow, amount, true, over}, _you), do: fill(:swing_critical, hit(amount, over))
  defp outcome(:miss, _you), do: fill(:swing_miss, %{})
  defp outcome(:foe_miss, _you), do: fill(:swing_miss, %{})

  defp outcome({:foe_blow, amount, _, :perfect, over}, you),
    do: fill(:foe_swing_perfect, shielded(hit(amount, over), you))

  defp outcome({:foe_blow, amount, _, :caught, over}, you),
    do: fill(:foe_swing_caught, shielded(hit(amount, over), you))

  defp outcome({:foe_blow, amount, true, nil, over}, _you),
    do: fill(:foe_swing_critical, hit(amount, over))

  defp outcome({:foe_blow, amount, false, nil, over}, _you),
    do: fill(:foe_swing_hit, hit(amount, over))

  defp join_and([only]), do: only
  defp join_and(parts), do: Enum.join(Enum.drop(parts, -1), ", ") <> " and " <> List.last(parts)

  # "you drink a Healing Potion and mend 112 HP, and you swing and hit for 9 damage"
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
