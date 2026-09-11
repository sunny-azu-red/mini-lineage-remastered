defmodule MiniLineageWeb.FallenCharacterTest do
  @moduledoc """
  The Character screen after death, which is a retrospective rather than a status page.

  Death keeps everything but health and effects, so the page has a whole run to show. What it must
  not do is talk as though the run were still going — a corpse has no next level to reach and no
  journey ahead, and the numbers beside the prose are the same ones the living screen renders.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias MiniLineage.Game.{Constants, Player, Snapshot}
  alias MiniLineageWeb.Screens

  defp html_for(player) do
    render_component(&Screens.screen/1,
      view: Snapshot.build(player),
      screen: "character",
      catalog: Snapshot.catalog(),
      flash: %{}
    )
  end

  defp living do
    {player, _} = Player.initialize(%Player{}, Constants.race(1), "Hero")
    %{player | experience: 4_200, adena: 900, total_battles: 12, total_enemies_killed: 30}
  end

  defp fallen, do: %{Player.kill(living()) | death_reason: "The road ran out beneath you."}

  describe "a fallen character" do
    test "is marked by the skull, not by its ancestry's emoji" do
      assert html_for(fallen()) =~ "☠️"
      refute html_for(fallen()) =~ Constants.race(1).emoji
    end

    test "speaks of the run in the past" do
      html = html_for(fallen())

      assert html =~ "were wielding"
      assert html =~ "struck with"
      assert html =~ "mended wounds"
      assert html =~ "Your Journey Has Ended"
      assert html =~ "You fell at"
    end

    test "and never as though it were still going" do
      html = html_for(fallen())

      refute html =~ "are wielding"
      refute html =~ "The Journey So Far"
      refute html =~ "journey ahead"
      refute html =~ "requiring another"
      # HP counting up would be the animation for a character that is regenerating.
      refute html =~ "char-vitality"
    end

    test "closes on the reason it ended, the same line the death screen carries" do
      assert html_for(fallen()) =~ "The road ran out beneath you."
    end

    test "and its way back leads to the death screen, which is the root" do
      # Start, Town and Game Over are one run's three states and share '/'. The Character screen is
      # somewhere you navigated to, so it has a URL; the screen it returns you to does not.
      html = html_for(fallen())

      assert html =~ "Return to your final rest"
      assert html =~ ~s|href="/"|
    end

    test "still shows the numbers the living screen shows, from the same markup" do
      html = html_for(fallen())

      for id <-
            ~w(char-stat-attack char-stat-defense char-stat-crit char-stat-regen char-stat-ambush),
          do: assert(html =~ id, id)

      assert html =~ "12 battles"
      assert html =~ "4,200 XP"
    end
  end

  describe "the prose itself" do
    # HEEx renders a line break as a space, so a span the formatter moved onto its own line puts
    # one in front of whatever punctuation follows: "Physical Defense ." Invisible in the markup.
    test "never leaves a space in front of its punctuation" do
      for player <- [
            living(),
            fallen(),
            %{living() | total_ambushes: 3},
            %{fallen() | total_ambushes: 3}
          ] do
        text =
          player |> html_for() |> String.replace(~r/<[^>]+>/, "") |> String.replace(~r/\s+/, " ")

        assert Regex.scan(~r/\S+ [,.]/, text) == [], text
      end
    end

    test "counts ambushes only when there were any" do
      refute html_for(fallen()) =~ "overcoming"
      assert html_for(%{fallen() | total_ambushes: 3}) =~ "overcoming"
      assert html_for(%{fallen() | total_ambushes: 3}) =~ "3 cunning ambushes"
    end

    test "and gives the reason it ended the same weight as the death screen does" do
      # Not muted: it is the last line of the eulogy, not a footnote to it. The reason is drawn at
      # random on death, so it is read off the same character that was rendered.
      player = fallen()
      html = html_for(player)
      reason = Regex.escape(player.death_reason)

      assert html =~ ~r|<p[^>]*>#{reason}|, "the reason it ended is not on the page"
      refute html =~ ~r|<p[^>]*class="[^"]*muted[^"]*"[^>]*>#{reason}|
    end
  end

  describe "a living character" do
    test "is untouched by any of it" do
      html = html_for(living())

      assert html =~ "are wielding"
      assert html =~ "The Journey So Far"
      assert html =~ "Continue your journey"
      refute html =~ "☠️"
      refute html =~ "You fell at"
    end
  end
end
