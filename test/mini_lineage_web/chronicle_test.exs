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
  # reads back, so the component may reach for all of them. The `ambushed` column and the ambush
  # line come from one flag in `Narrative.build_battle/3`, so a fixture that sets them apart would
  # be describing a row the game cannot write.
  defp fight(absent \\ []) do
    %{
      narrative: Map.merge(@lines, Map.new(absent, &{&1, nil})),
      ambushed: :ambush_line not in absent,
      died: false,
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

  defp text_for(chronicle) do
    chronicle
    |> html_for()
    |> String.replace(~r|<time[^>]*>.*?</time>|s, "")
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
      ambushed: true,
      died: false,
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
      ended = %{@complete | died: true, ambushed: false}

      assert html_for([ended], mine: true) =~ "You walk away"
      assert html_for([ended], mine: false) =~ "They walk away"
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

    # The one entry that is an ending rather than a report. Every other line of that fight was
    # dropped when it turned fatal, so this IS the entry, and it wears the colour an ending wears.
    test "and an ending wears the colour every ending in the game wears" do
      ended = %{fight([:crit_line, :kill_line, :deflection_line, :ambush_line]) | died: true}

      assert html_for([ended]) =~ ~s(<span class="deaths">)
      refute html_for([fight()]) =~ ~s(<span class="deaths">)
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
end
