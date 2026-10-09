defmodule MiniLineageWeb.ChronicleTest do
  @moduledoc """
  The Chronicle on a run's own page: every line a fight drew, in the order it drew them. Not a
  browser test, because a crit is rolled; here the narrative is handed in, and what
  is checked is which of its lines reach the page and in what order.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias MiniLineage.Game.Clock
  alias MiniLineageWeb.Screens.Record

  # Sentinels rather than real templates: a drawn line would make this a test of the pools.
  @lines %{
    crit_line: "CRIT!",
    kill_line: "KILL.",
    deflection_line: "DEFLECT.",
    outcome_line: "OUTCOME.",
    next_move: "MOVE"
  }

  # A line that did not happen is nil, never missing: `CharacterLog.to_battle/1` names every key it
  # reads back, so the component may reach for all of them.
  defp fight(absent \\ []) do
    %{
      id: System.unique_integer([:positive]),
      number: 1,
      narrative: Map.merge(@lines, Map.new(absent, &{&1, nil})),
      kind: "fight",
      at: ~U[2026-09-24 14:32:00Z]
    }
  end

  defp ms(at), do: DateTime.to_unix(at, :millisecond)

  defp html_for(record_log, opts \\ []),
    do:
      render_component(
        &Record.chronicle/1,
        opts |> Keyword.put(:record_log, record_log) |> Keyword.put(:record_id, "run")
      )

  # The entries on their own, so a claim about one is not answered by the panel around them.
  defp entries(chronicle) do
    [_, list] = Regex.run(~r|<ol[^>]*class="chronicle"[^>]*>(.*)</ol>|s, html_for(chronicle))

    list |> String.split("<li") |> Enum.drop(1)
  end

  # The head is asserted on its own; stripped here so a claim about the prose is not answered by it.
  defp text_for(chronicle, opts \\ []) do
    chronicle
    |> html_for(opts)
    |> String.replace(~r|<div class="entry-head">.*?</div>|s, "")
    |> String.replace(~r/<[^>]+>/, "")
    |> String.replace(~r/\s+/, " ")
  end

  # The defect this guards is silent: a line that is never voiced renders its pronouns as literal
  # braces on the page, and every OTHER line on the same entry reads perfectly.
  describe "every line on an entry" do
    @complete %{
      id: 1,
      number: 1,
      narrative: %{
        crit_line: "{whose} strike lands.",
        kill_line: "{they} cut down the {object} before {them}.",
        deflection_line: "{whose} armour held, and {them} learned from it.",
        outcome_line: "{they} walk away, {self} again.",
        next_move: "MOVE"
      },
      kind: "fight",
      at: ~U[2026-09-24 14:32:00Z]
    }

    for {who, mine?} <- [{"the run itself", true}, {"anybody else", false}] do
      test "closes its pronouns for #{who}" do
        html = html_for([@complete], mine: unquote(mine?))
        [_, entry] = Regex.run(~r|<ol[^>]*class="chronicle"[^>]*>(.*)</ol>|s, html)

        assert Regex.scan(~r/\{[a-z]+\}/, entry) == [],
               "a line reached the page with its pronouns still open: #{entry}"
      end
    end

    test "and an ending is told to whoever is reading it, not to the run that had it" do
      ended = %{
        id: 2,
        number: 2,
        kind: "ending",
        line: @complete.narrative.outcome_line,
        at: @complete.at
      }

      assert html_for([ended], mine: true) =~ "You walk away"
      assert html_for([ended], mine: false) =~ "They walk away"
    end
  end

  # Everything a run did that was not a fight: one sentence, and the same open pronouns.
  defp deed(kind, line),
    do: %{
      id: System.unique_integer([:positive]),
      number: 1,
      kind: kind,
      line: line,
      at: ~U[2026-09-24 14:33:00Z]
    }

  describe "a deed in the Chronicle" do
    test "is one line, told to whoever is reading it" do
      bought = deed("purchase", "{they} took up the 🗡️ Sword.")

      assert text_for([bought], mine: true) =~ "You took up the 🗡️ Sword."
      assert text_for([bought], mine: false) =~ "They took up the 🗡️ Sword."
    end

    test "and an ending wears the colour every ending in the game wears" do
      [entry] = entries([deed("ending", "💀 Fate has claimed {their} soul.")])

      assert entry =~ ~s(<span class="deaths">)
      assert entry =~ "Fate has claimed"
    end

    # The gods noticing is not the same as dying, and the game colours them differently.
    test "and a heresy is marked, but it is not an ending" do
      [entry] = entries([deed("cheat", "👾 The gods saw {their} heresy.")])

      assert entry =~ ~s(<span class="heretics">)
      refute entry =~ "deaths"
    end

    # A value named inside a sentence, like Adena or a level: a classed span that takes its weight
    # from the vocabulary, never a `<strong>`.
    test "names an effect the way it names any other value" do
      mark = MiniLineage.Game.Constants.effect(:konami_cheat)

      line =
        MiniLineage.Game.Narrative.build_effect_change(
          MiniLineage.Game.Narratives.effect_gained(),
          mark
        )

      [entry] = entries([deed("debuff", line)])

      assert entry =~ ~s(<span class="debuff">Cheater's Mark</span>)
      refute entry =~ "<strong"
    end

    # A class only where the stylesheet paints one, each washed like the alert that would announce
    # it, and never a `class=""` on a quiet row.
    test "wears a class only where it is painted" do
      [start, bought, levelled, blessed, quiet] =
        entries([
          deed("start", "{they} chose the 🧟 Orc."),
          deed("purchase", "{they} took up the 🗡️ Sword."),
          deed("level_up", "{they} reached Level 4."),
          deed("buff", "🐣 Newbie Blessing settles over {object}."),
          fight()
        ])

      assert own_tag(start) =~ ~s(class="start")
      assert own_tag(bought) =~ ~s(class="purchase")
      assert own_tag(levelled) =~ ~s(class="level-up")
      refute own_tag(blessed) =~ "class"
      refute own_tag(quiet) =~ "class"
    end

    # Its head says when, then what kind of deed it was. Every ending is an Ending, whether a blow
    # or the run's own hand did it, the pair of the Beginning.
    test "is headed by when it happened and what kind of thing it was" do
      heads =
        [
          deed("start", "x"),
          fight(),
          deed("purchase", "x"),
          deed("level_up", "x"),
          deed("buff", "x"),
          deed("debuff", "x"),
          deed("cheat", "x"),
          deed("ending", "x")
        ]
        |> entries()
        |> Enum.map(&head/1)

      assert heads == [
               "Beginning",
               "Battle",
               "Purchase",
               "Level Up",
               "Buff",
               "Debuff",
               "Cheat",
               "Ending"
             ]

      Clock.put_now(ms(~U[2026-09-24 14:36:00Z]))

      assert hd(entries([fight()])) =~
               ~r|<div class="entry-head">\s*<span>.*4m ago.*&bull; Battle</span>|s
    end

    # The row id is the whole table's and says nothing about the run; the number is its place in it,
    # and stands apart from the date so the two never read as one label.
    test "and names its place in the run on the right, apart from when and what it was" do
      [entry] = entries([%{deed("purchase", "x") | id: 9_041, number: 7}])

      assert entry =~ ~r|&bull; Purchase</span>\s*<span>&num;7</span>\s*</div>|
      refute entry =~ "&num;9041"
    end

    # The same silent defect the fight lines have: an unvoiced line renders its braces on the page
    # and every other line on the same list reads perfectly.
    test "and closes its pronouns, whoever is reading" do
      every_kind = [
        deed("start", "{they} chose the 🧟 Orc, and {their} destiny awaits."),
        deed("purchase", "{they} took up the 🗡️ Sword."),
        deed("level_up", "{they} reached Level 4."),
        deed("cheat", "👾 The gods saw {their} heresy, and closed the book on {object}."),
        deed("ending", "💀 Fate has claimed {their} soul.")
      ]

      for mine <- [true, false] do
        [_, list] =
          Regex.run(
            ~r|<ol[^>]*class="chronicle"[^>]*>(.*)</ol>|s,
            html_for(every_kind, mine: mine)
          )

        assert Regex.scan(~r/\{[a-z]+\}/, list) == [],
               "a deed went unvoiced for mine: #{mine}"
      end
    end
  end

  describe "an entry in the Chronicle" do
    test "tells every line of the fight, in the order the fight drew them" do
      text = text_for([fight()])

      # One assertion, because the spaces are half the claim: two lines rendered flush against each
      # other read as "KILL.DEFLECT." to somebody trying to follow what happened.
      assert text =~ "CRIT! KILL. DEFLECT. OUTCOME."
    end

    test "but never the one that is a button rather than history" do
      text = text_for([fight()])

      refute text =~ "MOVE"
    end

    test "leaves out the crit it never landed, without leaving a gap where it would have been" do
      text = text_for([fight([:crit_line])])

      refute text =~ "CRIT!"
      assert text =~ "KILL. DEFLECT. OUTCOME."
    end

    test "is one of however many the run has, in the order it is handed them" do
      text = text_for([fight([:crit_line]), fight()])

      assert text =~ "KILL. DEFLECT. OUTCOME. CRIT! KILL. DEFLECT. OUTCOME."
    end

    # Short, being a log's head: an age while the run is recent, and past the cap a date that keeps
    # its time, since a day of play crowds one date with entries.
    test "and says when it happened, as an age and then as a date" do
      Clock.put_now(ms(~U[2026-09-24 19:32:00Z]))
      [recent] = entries([fight()])

      assert recent =~ ~s(datetime="2026-09-24T14:32:00Z")
      assert recent =~ ~s(title="24 Sep 2026, 2:32 pm")
      assert recent =~ ">5h ago</time>"

      Clock.put_now(ms(~U[2026-10-01 14:32:00Z]))
      assert hd(entries([fight()])) =~ ">24 Sep, 2:32 pm</time>"
    end

    # A hook per row is fifty hooks doing one job, so the list carries it instead.
    test "under one hook for the whole list, never one per entry" do
      html = html_for([fight(), fight()])

      assert [_] = Regex.scan(~r/phx-hook="Stamps"/, html)
    end

    test "and a run with no fights says so instead" do
      assert text_for([]) =~ "Not one blow struck"
    end

    # A fatal fight is logged as an ending, so a fight row is always one the run walked away from.
    test "and is never drawn as an ending" do
      refute html_for([fight()]) =~ ~s(class="deaths")
    end
  end

  # The row's own opening tag, up to the first `>`: the spans inside carry classes of their own.
  defp own_tag(entry), do: entry |> String.split(">", parts: 2) |> hd()

  defp head(entry) do
    [_, head] = Regex.run(~r|<div class="entry-head">\s*<span>(.*?)</span>|s, entry)
    head |> String.split("&bull;") |> List.last() |> String.trim()
  end
end
