defmodule MiniLineageWeb.DeathScreenTest do
  @moduledoc """
  How a run's ending is shown. There is one ending, however it was reached: a heresy is not a
  warning but the last line of the run, as the fallen Character screen closes on it too.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias MiniLineage.Game.{Actions, Constants, Player, Snapshot, Narrative}

  alias MiniLineageWeb.Screens

  defp hero do
    {player, _} = Player.initialize(%Player{}, Constants.race(1), :fighter, "Hero")
    player
  end

  defp html_for(player) do
    render_component(&Screens.screen/1,
      view: Snapshot.build(player),
      screen: "death",
      catalog: Snapshot.catalog()
    )
  end

  defp endings do
    {cheater, _} = Actions.cheat(hero())

    # A drawn death line may carry an apostrophe HEEx escapes, so matching it would pass or fail
    # on the roll. That every line comes from the pool is death_test's job.
    fell = %{Player.kill(hero()) | death_reason: "The road ran out beneath you."}

    [
      {"fell in battle", fell},
      {"was struck down for cheating", Player.kill(cheater)}
    ]
  end

  describe "the reason it ended" do
    test "is prose on every ending, never an alert to be dismissed" do
      for {label, player} <- endings() do
        html = html_for(player)

        refute html =~ "alert", "#{label} is shown as an alert"
        spoken = Narrative.death_reason(player.death_reason, true)

        assert html =~ ~r|<p[^>]*>\s*<span class="deaths">#{Regex.escape(spoken)}</span>|, label
      end
    end

    test "and each ending has its own line" do
      reasons = Enum.map(endings(), fn {_, player} -> player.death_reason end)

      assert length(Enum.uniq(reasons)) == length(endings())
      assert Enum.all?(reasons, &(&1 != nil and &1 != ""))
    end
  end

  describe "what a player may do from here" do
    test "the ending is red and what became of it is not" do
      html = html_for(Player.kill(hero()))

      # On a SPAN inside the paragraph, which is what the weight rule reaches: a `p.deaths` is
      # coloured but not weighted, and the ending should read as it does in the chronicle.
      assert html =~ ~r|<p[^>]*>\s*<span class="deaths">|
      refute html =~ ~s(<p class="deaths">)
      refute html =~ ~s(class="muted")
    end

    test "is not offered to a run the Hall will not list" do
      {cheater, _} = Actions.cheat(hero())

      html = html_for(Player.kill(cheater))

      refute html =~ "The Hall of", "a barred run is pointed at a board it is not on"
      assert html =~ "Play Again?", "and is left with the one thing it can still do"
    end

    test "points at the Halls of its own lineage, not back at its own record" do
      # The sidebar already links the record, so a second link would be a second door into the
      # same room.
      html = html_for(Player.kill(hero()))

      assert html =~ ~s(href="/highscores/orc")
      assert html =~ "The Hall of Orc Champions"
      refute html =~ "Your Record"
    end

    test "starting over is an ordinary button — a new run needs no new cookie" do
      html = html_for(Player.kill(hero()))

      assert html =~ ~s(phx-click="restart")
      refute html =~ "/play-again", "the session survives the run; only the character changes"
      refute html =~ "Write your Legacy", "the board no longer waits to be written to"
    end

    test "says what the chroniclers did with the run, and it is not the same for everyone" do
      {cheater, _} = Actions.cheat(hero())

      assert html_for(Player.kill(cheater)) =~ "scraped your name from the stone"
      assert html_for(Player.kill(hero())) =~ "cut your deeds into the hallowed pillars"
    end

    test "but anyone may start again" do
      for {label, player} <- endings(), do: assert(html_for(player) =~ "Play Again?", label)
    end
  end
end
