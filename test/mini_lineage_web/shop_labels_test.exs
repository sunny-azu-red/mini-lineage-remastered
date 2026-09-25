defmodule MiniLineageWeb.ShopLabelsTest do
  @moduledoc """
  A column label is markup, written the way the rest of the game writes it: a character with a
  named entity is written as the entity. The one that needs it binds the percent to its word, so a
  label that wraps on a phone never strands a lone "%".
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias MiniLineage.Game.{Constants, Player, Snapshot}

  defp weapons do
    {player, _} = Player.initialize(%Player{}, Constants.race(1), "Hero")

    render_component(&MiniLineageWeb.Screens.screen/1,
      view: Snapshot.build(%{player | current_screen: "weapons"}),
      screen: "weapons",
      catalog: Snapshot.catalog()
    )
  end

  test "bind a unit with the named entity, not an invisible character" do
    html = weapons()

    assert html =~ ">C. Hit&nbsp;%</th>"
    refute html =~ " "
    # Escaped, it would print the five characters on the page.
    refute html =~ "&amp;nbsp;"
  end
end
