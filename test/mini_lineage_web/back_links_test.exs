defmodule MiniLineageWeb.BackLinksTest do
  @moduledoc """
  Every way back, across every state that can reach it. A back link can be wrong without looking
  broken: the destination can be right while its words promise a journey that has not begun.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias MiniLineage.Game.{Access, Constants, Player, Snapshot}
  alias MiniLineageWeb.Screens

  @places [
    {"start", nil},
    {"town", "orc-village"},
    {"gatekeeper", "orc-village"},
    {"races", nil},
    {"error", nil}
  ]

  defp states do
    {started, _} = Player.initialize(%Player{}, Constants.race(1), :fighter, "Hero")

    [unstarted: %Player{}, started: started]
  end

  defp render(screen, player, detail \\ nil) do
    render_component(&Screens.screen/1,
      view: Snapshot.build(player),
      screen: screen,
      catalog: Snapshot.catalog(),
      detail: detail
    )
  end

  defp links(html) do
    ~r|<a[^>]*href="([^"]+)"[^>]*>\s*([^<]+?)\s*</a>|s
    |> Regex.scan(html)
    |> Enum.map(fn [_, href, text] -> {href, String.replace(text, ~r/\s+/, " ")} end)
  end

  test "a visitor is never told to continue a journey they have not begun" do
    visitor = states()[:unstarted]

    for {screen, _town} = place <- @places,
        Access.pin_screen(place, visitor) == place,
        {_href, text} <- links(render(screen, visitor)) do
      refute text =~ ~r/continue your journey/i, "#{screen} offers a visitor #{inspect(text)}"
    end
  end

  test "and a character is never sent back to a start it is past" do
    started = states()[:started]

    for {screen, _town} = place <- @places,
        Access.pin_screen(place, started) == place,
        {_href, text} <- links(render(screen, started)) do
      refute text =~ ~r/game start/i, "#{screen} offers a character #{inspect(text)}"
    end
  end

  # The same way out as the page Phoenix draws, since both are the same apology.
  test "the error screen rules off its way back only when no fault stands above it to do so" do
    started = states()[:started]

    assert render("error", started) =~ ~s(class="last back")
    refute render("error", started, "boom") =~ ~s(class="last back")
    assert render("error", started, "boom") =~ "code-block"
  end
end
