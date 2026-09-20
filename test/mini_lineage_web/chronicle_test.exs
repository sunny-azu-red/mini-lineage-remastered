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
  # reads back, so the component may reach for all of them. Only `narrative` is read here; the rest
  # of a row is the numbers, which the paragraphs above the Chronicle carry.
  defp fight(absent \\ []),
    do: %{narrative: Map.merge(@lines, Map.new(absent, &{&1, nil}))}

  defp text_for(chronicle) do
    {player, _} = Player.initialize(%Player{}, Constants.race(1), "Hero")

    render_component(&Record.record/1,
      view: Snapshot.build(player),
      catalog: Snapshot.catalog(),
      chronicle: chronicle
    )
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
  end
end
