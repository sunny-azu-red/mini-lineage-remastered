defmodule MiniLineageWeb.DeathScreenTest do
  @moduledoc """
  How a run's ending is shown.

  There is one ending, however it was reached. A suicide and a heresy are not warnings to be
  dismissed — they are the last line of the run, and they read as one, the same way the fallen
  Character screen closes on the same sentence.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias MiniLineage.Game.{Actions, Constants, Player, Snapshot}
  alias MiniLineageWeb.Screens

  defp hero do
    {player, _} = Player.initialize(%Player{}, Constants.race(1), "Hero")
    player
  end

  defp html_for(player) do
    render_component(&Screens.screen/1,
      view: Snapshot.build(player),
      screen: "death",
      catalog: Snapshot.catalog(),
      flash: %{}
    )
  end

  defp endings do
    {cheater, _} = Actions.cheat(hero())

    # A death in battle draws its line at random, and some of them carry an apostrophe that HEEx
    # escapes — matching the raw string would then pass or fail on the roll. The coward's and the
    # cheater's are fixed strings already. That every line comes from the pool is death_test's job.
    fell = %{Player.kill(hero()) | death_reason: "The road ran out beneath you."}

    [
      {"fell in battle", fell},
      {"took their own life", Player.commit_suicide(hero())},
      {"was struck down for cheating", Player.kill(cheater)}
    ]
  end

  describe "the reason it ended" do
    test "is prose on every ending, never an alert to be dismissed" do
      for {label, player} <- endings() do
        html = html_for(player)

        refute html =~ "alert", "#{label} is shown as an alert"
        assert html =~ ~r|<p[^>]*>\s*#{Regex.escape(player.death_reason)}|, label
      end
    end

    test "and each ending has its own line" do
      reasons = Enum.map(endings(), fn {_, player} -> player.death_reason end)

      assert length(Enum.uniq(reasons)) == 3
      assert Enum.all?(reasons, &(&1 != nil and &1 != ""))
    end

    test "with a cheater's heresy outranking a coward's exit, having done both" do
      {cheater, _} = Actions.cheat(hero())
      both = Player.commit_suicide(cheater)

      assert both.coward and both.cheated
      assert both.death_reason =~ "heresy"
    end
  end

  describe "what a player may do from here" do
    test "a legitimate death may write its legacy" do
      assert html_for(Player.kill(hero())) =~ "Write your Legacy"
    end

    test "and a coward or a cheater may not" do
      {cheater, _} = Actions.cheat(hero())

      refute html_for(Player.commit_suicide(hero())) =~ "Write your Legacy"
      refute html_for(Player.kill(cheater)) =~ "Write your Legacy"
    end

    test "but anyone may start again" do
      for {label, player} <- endings(), do: assert(html_for(player) =~ "Play Again?", label)
    end
  end
end
