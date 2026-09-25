defmodule MiniLineageWeb.BackLinksTest do
  @moduledoc """
  Every way back, across every state that can reach it.

  A back link can be wrong without looking broken: the Halls sent a dead player to '/', which
  renders their ending, while promising to continue a journey that was over. The destination was
  right and only the words lied, so following it proved nothing.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias MiniLineage.Game.{Access, Constants, Player, Snapshot}
  alias MiniLineageWeb.Screens

  @screens ~w(error races statistics highscores character battle home inn weapons armors suicide
              death start)

  defp states do
    {alive, _} = Player.initialize(%Player{}, Constants.race(1), "Hero")

    [unstarted: %Player{}, alive: alive, dead: Player.kill(alive)]
  end

  # The run a Character screen draws is not the player reading it — a visitor with no character of
  # their own can open anybody's record. So the subject is its own started run, and a record is
  # never nil: an id nobody has is a 404 long before anything is rendered.
  defp subject do
    {player, _} = Player.initialize(%Player{}, Constants.race(1), "Somebody")
    player
  end

  defp render(screen, player) do
    viewing? = screen == "character"

    render_component(&Screens.screen/1,
      view: Snapshot.build(player),
      screen: screen,
      catalog: Snapshot.catalog(),
      boards: %{},
      statistics: nil,
      record:
        viewing? &&
          %{
            id: "somebody",
            name: "Somebody",
            inserted_at: DateTime.utc_now(),
            last_seen_at: DateTime.utc_now(),
            active: true,
            dead: false
          },
      record_view: viewing? && Snapshot.build(subject()),
      record_log: [],
      from: nil
    )
  end

  defp links(html) do
    ~r|<a[^>]*href="([^"]+)"[^>]*>\s*([^<]+?)\s*</a>|s
    |> Regex.scan(html)
    |> Enum.map(fn [_, href, text] -> {href, String.replace(text, ~r/\s+/, " ")} end)
  end

  describe "a player who has died" do
    test "is never invited to carry on, on any screen they can reach" do
      for screen <- @screens,
          dead = states()[:dead],
          Access.pin_screen(screen, dead) == screen,
          {_href, text} <- links(render(screen, dead)) do
        refute text =~ ~r/continue|journey ahead|game start/i,
               "#{screen} offers the dead #{inspect(text)}"
      end
    end

    test "and where a screen names their way out, it is their ending" do
      dead = states()[:dead]

      for screen <- ~w(highscores),
          {href, text} <- links(render(screen, dead)),
          text =~ ~r/return|back/i do
        assert href == "/", "#{screen}: #{inspect(text)} -> #{href}"
        assert text =~ "final rest", "#{screen} says #{inspect(text)} to someone who has died"
      end
    end
  end

  describe "a visitor with no character" do
    test "is never told to continue a journey they have not begun" do
      for screen <- @screens,
          visitor = states()[:unstarted],
          Access.pin_screen(screen, visitor) == screen,
          {_href, text} <- links(render(screen, visitor)) do
        refute text =~ ~r/continue your journey|final rest/i,
               "#{screen} offers a visitor #{inspect(text)}"
      end
    end
  end

  describe "the shops and Suicide" do
    test "carry no back link at all — their select is the way out" do
      alive = states()[:alive]

      for screen <- ~w(inn weapons armors suicide) do
        refute render(screen, alive) =~ "last back",
               "#{screen} grew a back link; its form is meant to be the only way out"
      end
    end
  end
end
