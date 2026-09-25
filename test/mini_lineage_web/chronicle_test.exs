defmodule MiniLineageWeb.ChronicleTest do
  @moduledoc """
  The Chronicle on a run's own page: every line a fight drew, in the order it drew them.

  Not a browser test, because the browser cannot make the dice land — a crit and an ambush are
  rolled, so the two lines that only appear for them would be asserted on a coin toss. Here the
  narrative is handed in, and what is checked is which of its lines reach the page and in what
  order.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias MiniLineageWeb.Screens.Record

  # Sentinels rather than real templates: a drawn line would make this a test of the pools.
  @lines %{
    crit_line: "CRIT!",
    kill_line: "KILL.",
    deflection_line: "DEFLECT.",
    outcome_line: "OUTCOME.",
    ambush_line: "AMBUSH.",
    fight_prompt: "PROMPT",
    next_move: "MOVE"
  }

  # A line that did not happen is nil, never missing: `CharacterLog.to_battle/1` names every key it
  # reads back, so the component may reach for all of them. `ambushed` is derived from the ambush
  # line, so a fixture that sets them apart would be describing a row the game cannot produce.
  defp fight(absent \\ []) do
    %{
      narrative: Map.merge(@lines, Map.new(absent, &{&1, nil})),
      kind: "fight",
      ambushed: :ambush_line not in absent,
      at: ~U[2026-09-24 14:32:00Z]
    }
  end

  defp html_for(record_log, opts \\ []),
    do: render_component(&Record.chronicle/1, Keyword.put(opts, :record_log, record_log))

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
  # braces on the page, and every OTHER line on the same entry reads perfectly. Nothing fails, so
  # nothing says so — which is exactly how an ambush line and a death line both shipped unvoiced.
  describe "every line on an entry" do
    @complete %{
      narrative: %{
        crit_line: "{whose} strike lands.",
        kill_line: "{they} cut down the {object} before {them}.",
        deflection_line: "{whose} armour held, and {them} learned from it.",
        outcome_line: "{they} walk away, {self} again.",
        ambush_line: "Something waits for {object}, and {them} cannot pass.",
        fight_prompt: "PROMPT",
        next_move: "MOVE"
      },
      kind: "fight",
      ambushed: true,
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
      ended = %{kind: "ending", line: @complete.narrative.outcome_line, at: @complete.at}

      assert html_for([ended], mine: true) =~ "You walk away"
      assert html_for([ended], mine: false) =~ "They walk away"
    end
  end

  # Everything a run did that was not a fight: one sentence, and the same open pronouns.
  defp deed(kind, line),
    do: %{kind: kind, line: line, at: ~U[2026-09-24 14:33:00Z]}

  describe "a deed in the Chronicle" do
    test "is one line, told to whoever is reading it" do
      bought = deed("purchase", "{they} took up the 🗡️ Sword.")

      assert text_for([bought], mine: true) =~ "You took up the 🗡️ Sword."
      assert text_for([bought], mine: false) =~ "They took up the 🗡️ Sword."
    end

    # A run that ends in a fight has the fight row to say so; one that ends by its own hand had
    # nothing at all, and the Chronicle simply stopped.
    test "and an ending wears the colour every ending in the game wears" do
      [entry] = entries([deed("ending", "🤡 {they} took the cowardly way out.")])

      assert entry =~ ~s(<span class="deaths">)
      assert entry =~ "took the cowardly way out"
    end

    # The gods noticing is not the same as dying, and the game colours them differently.
    test "and a heresy is marked, but it is not an ending" do
      [entry] = entries([deed("cheat", "👾 The gods saw {their} heresy.")])

      assert entry =~ ~s(<span class="heretics">)
      refute entry =~ "deaths"
    end

    # A value named inside a sentence, like Adena or a level: a classed span that takes its weight
    # from the vocabulary. `<strong>` said "important" to no end, the weight rule outranks it.
    test "names an effect the way it names any other value" do
      hexed = MiniLineage.Game.Constants.effect(:ambush_debuff)

      line =
        MiniLineage.Game.Narrative.build_effect_change(
          MiniLineage.Game.Narratives.effect_gained(),
          hexed
        )

      [entry] = entries([deed("debuff", line)])

      assert entry =~ ~s(<span class="debuff">Hexed</span>)
      refute entry =~ "<strong"
    end

    # A class only where the stylesheet paints one, each washed like the alert that would announce
    # it; `class=""` on every quiet row was the AGENTS rule about class lists, broken.
    test "wears a class only where it is painted" do
      [start, bought, levelled, blessed, quiet] =
        entries([
          deed("start", "{they} chose the 🧟 Orc."),
          deed("purchase", "{they} took up the 🗡️ Sword."),
          deed("level_up", "{they} reached Level 4."),
          deed("buff", "🐣 Newbie Blessing settles over {object}."),
          fight([:ambush_line])
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

      assert hd(entries([fight()])) =~
               ~r|<div class="entry-head">.*24/09/26, 14:32.*&bull; Battle\s*</div>|s
    end

    # The same silent defect the fight lines have: an unvoiced line renders its braces on the page
    # and every other line on the same list reads perfectly.
    test "and closes its pronouns, whoever is reading" do
      every_kind = [
        deed("start", "{they} chose the 🧟 Orc, and {their} destiny awaits."),
        deed("purchase", "{they} took up the 🗡️ Sword."),
        deed("level_up", "{they} reached Level 4."),
        deed("cheat", "👾 The gods saw {their} heresy, and closed the book on {object}."),
        deed("ending", "🤡 {they} took the cowardly way out.")
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
      assert text =~ "CRIT! KILL. DEFLECT. OUTCOME. AMBUSH."
    end

    test "but never the two that are buttons rather than history" do
      text = text_for([fight()])

      refute text =~ "PROMPT"
      refute text =~ "MOVE"
    end

    test "leaves out the crit it never landed, without leaving a gap where it would have been" do
      text = text_for([fight([:crit_line])])

      refute text =~ "CRIT!"
      assert text =~ "KILL. DEFLECT. OUTCOME."
    end

    test "and the ambush that never came" do
      text = text_for([fight([:ambush_line])])

      refute text =~ "AMBUSH."
      assert text =~ "KILL. DEFLECT. OUTCOME."
    end

    test "is one of however many the run has, oldest first" do
      text = text_for([fight([:crit_line, :ambush_line]), fight([:crit_line])])

      assert text =~ "KILL. DEFLECT. OUTCOME. KILL. DEFLECT. OUTCOME. AMBUSH."
    end

    # The reader's own clock corrects it; the markup has to carry the instant for that to be
    # possible, and the UTC text has to be right for a reader with no JS at all.
    test "and says when it happened" do
      [entry] = entries([fight()])

      assert entry =~ ~s(datetime="2026-09-24T14:32:00Z")
      assert entry =~ "24/09/26, 14:32"
    end

    # A hook per row is a hundred hooks doing one job, so the list carries it instead.
    test "under one hook for the whole list, never one per entry" do
      html = html_for([fight(), fight()])

      assert html =~ ~s(phx-hook="LocalTimes")
      refute html =~ ~r/phx-hook="LocalTime"/
    end

    test "and a run with no fights says so instead" do
      assert text_for([]) =~ "Not one blow struck"
    end

    # A fatal fight is logged as an ending, so a fight row is always one the run walked away from.
    test "and is never drawn as an ending" do
      refute html_for([fight()]) =~ ~s(class="deaths")
    end

    # The class is the claim, not the colour: what red means lives in the stylesheet, and a test
    # reading that back would only assert that CSS is spelled the way it is spelled.
    test "wears the ambush it ended in, so a run of them is visible without reading a word" do
      [quiet, caught] = entries([fight([:ambush_line]), fight()])

      assert caught =~ "AMBUSH."
      assert caught =~ ~s(class="ambushed")
      # And the fight nothing was waiting after is left alone, or the mark says nothing.
      refute quiet =~ "AMBUSH."
      refute quiet =~ "ambushed"
    end
  end

  # The row's own opening tag, up to the first `>`: the spans inside carry classes of their own.
  defp own_tag(entry), do: entry |> String.split(">", parts: 2) |> hd()

  defp head(entry) do
    [_, head] = Regex.run(~r|<div class="entry-head">(.*?)</div>|s, entry)
    head |> String.split("&bull;") |> List.last() |> String.trim()
  end
end
