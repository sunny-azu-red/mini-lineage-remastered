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
  alias MiniLineageWeb.{Screens, Screens.Record}

  # The component, not the screen: these are about the prose, and `record/1` is what carries it
  # for a reader of any kind.
  defp html_for(player, mine \\ true) do
    render_component(&Record.record/1,
      view: Snapshot.build(player),
      catalog: Snapshot.catalog(),
      mine: mine
    )
  end

  # What a reader sees, with the markup taken out. A figure and the noun it counts are separate
  # elements now, because only the figure animates — so "12 battles" is prose, not markup, and
  # asserting on it against raw HTML would only be asserting on where the spans happen to fall.
  defp text_for(player, mine \\ true) do
    player |> html_for(mine) |> String.replace(~r/<[^>]+>/, "") |> String.replace(~r/\s+/, " ")
  end

  defp living do
    {player, _} = Player.initialize(%Player{}, Constants.race(1), "Hero")
    %{player | experience: 4_200, adena: 900, total_battles: 12, total_enemies_killed: 30}
  end

  defp fallen,
    do: %{Player.kill(living()) | death_reason: "The road ran out beneath {object}."}

  describe "the way back, for someone who has died" do
    defp halls_for(player) do
      render_component(&Screens.screen/1,
        view: Snapshot.build(player),
        screen: "highscores",
        catalog: Snapshot.catalog(),
        boards: %{},
        flash: %{}
      )
    end

    test "leads to their ending, and says so" do
      # The destination was already right — '/' renders the death screen for the dead — but the
      # label promised a journey that is over.
      html = halls_for(fallen())

      assert html =~ "Return to your final rest"
      refute html =~ "Continue your journey"
    end

    test "while the living are told to carry on" do
      html = halls_for(living())

      assert html =~ "Continue your journey"
      refute html =~ "Return to your final rest"
    end
  end

  describe "the voice" do
    test "is second person on your own record" do
      html = html_for(fallen())

      assert html =~ "You were wielding"
      assert html =~ "Your Journey Has Ended"
      refute html =~ "They were wielding"
    end
  end

  describe "a fallen character" do
    test "keeps its ancestry's emoji rather than swapping in a skull" do
      # A skull in place of the badge loses the one glyph that says which lineage this was, to
      # repeat something the prose below already says in words.
      html = html_for(fallen())

      assert html =~ Constants.race(1).emoji
      refute html =~ "☠️"
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

    # The record tallies the run; the CHRONICLE tells how it ended, as the last fight it ever had.
    # Saying it in both left the page repeating itself two paragraphs apart.
    test "tallies the run without repeating how it ended" do
      refute html_for(fallen()) =~ "The road ran out beneath you."
      assert html_for(fallen()) =~ "You fell at"
    end

    test "and reads as somebody else's when somebody else is reading it" do
      # Never the name in the prose — the heading has already said whose record this is.
      html = html_for(fallen(), false)

      assert html =~ "Their Journey Has Ended"
      assert html =~ "Their journey across the realm was"
      assert html =~ "They fell at"
      refute html =~ "You fell at"
    end

    test "still shows the numbers the living screen shows, from the same markup" do
      html = html_for(fallen())

      for id <-
            ~w(char-stat-attack char-stat-defense char-stat-crit char-stat-regen char-stat-ambush),
          do: assert(html =~ id, id)

      text = text_for(fallen())
      assert text =~ "12 battles"
      assert text =~ "4,200 XP"
    end

    test "and what its gear granted counts too, rather than jumping with the gear" do
      crit? = &((Snapshot.item_view(&1)[:crit] || 0) > 0)
      regen? = &((Snapshot.item_view(&1)[:regen] || 0) > 0)

      html =
        html_for(%{
          fallen()
          | weapon_id: Enum.find_index(Constants.weapons(), crit?),
            armor_id: Enum.find_index(Constants.armors(), regen?)
        })

      assert html =~ ~s|data-key="rec-weapon-crit"|
      assert html =~ ~s|data-key="rec-armor-regen"|
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
        text = text_for(player)

        assert Regex.scan(~r/\S+ [,.]/, text) == [], text
      end
    end

    test "counts ambushes only when there were any" do
      refute html_for(fallen()) =~ "overcoming"
      assert html_for(%{fallen() | total_ambushes: 3}) =~ "overcoming"
      assert text_for(%{fallen() | total_ambushes: 3}) =~ "3 cunning ambushes"
    end

    test "and leaves the ending to the one entry that is an ending" do
      # How a run ended is the last line of its chronicle, in the red every ending in the game
      # wears. The record's own prose counts what it did and stops there.
      html = html_for(fallen())

      refute html =~ ~s(<span class="deaths">)
      assert html =~ "when the road ran out."
    end
  end

  describe "a living character" do
    test "is untouched by any of it" do
      html = html_for(living())

      assert html =~ "are wielding"
      assert html =~ "The Journey So Far"
      assert html =~ "The Journey So Far"
      refute html =~ "☠️"
      refute html =~ "You fell at"
    end
  end
end
