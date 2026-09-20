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

  alias MiniLineage.Game.{Constants, Player, Snapshot}
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

  # A line that did not happen is nil, never missing: `BattleLog.to_battle/1` names every key it
  # reads back, so the component may reach for all of them. The `ambushed` column and the ambush
  # line come from one flag in `Narrative.build_battle/3`, so a fixture that sets them apart would
  # be describing a row the game cannot write.
  defp fight(absent \\ []) do
    %{
      narrative: Map.merge(@lines, Map.new(absent, &{&1, nil})),
      ambushed: :ambush_line not in absent
    }
  end

  defp html_for(chronicle) do
    {player, _} = Player.initialize(%Player{}, Constants.race(1), "Hero")

    render_component(&Record.record/1,
      view: Snapshot.build(player),
      catalog: Snapshot.catalog(),
      chronicle: chronicle
    )
  end

  # The entries on their own, so a claim about one is not answered by something elsewhere on a page
  # that talks about ambush risk in two other places.
  defp entries(chronicle) do
    [_, list] = Regex.run(~r|<ol class="chronicle">(.*)</ol>|s, html_for(chronicle))

    list |> String.split("<li") |> Enum.drop(1)
  end

  defp text_for(chronicle) do
    chronicle
    |> html_for()
    |> String.replace(~r/<[^>]+>/, "")
    |> String.replace(~r/\s+/, " ")
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

    test "and a run with no fights says so instead" do
      assert text_for([]) =~ "Not one blow struck"
    end

    # The class is the claim, not the colour: what red means lives in the stylesheet, and a test
    # reading that back would only assert that CSS is spelled the way it is spelled.
    test "wears the ambush it ended in, so a run of them is visible without reading a word" do
      [quiet, caught] = entries([fight([:ambush_line]), fight()])

      assert caught =~ "AMBUSH."
      assert caught =~ ~s(class="alert alert-danger")
      # And the fight nothing was waiting after is left alone, or the mark says nothing.
      refute quiet =~ "AMBUSH."
      refute quiet =~ "alert"
    end
  end
end
