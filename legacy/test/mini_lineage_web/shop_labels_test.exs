defmodule MiniLineageWeb.ShopLabelsTest do
  @moduledoc """
  A column label is markup, written the way the rest of the game writes it: a character with a
  named entity is written as the entity, never as an invisible character or an escaped one.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias MiniLineage.Game.{Constants, Player, Snapshot}

  defp weapons do
    {player, _} = Player.initialize(%Player{}, Constants.race(1), :fighter, "Hero")

    render_component(&MiniLineageWeb.Screens.screen/1,
      view: Snapshot.build(%{player | current_screen: "weapons"}),
      screen: "weapons",
      catalog: Snapshot.catalog()
    )
  end

  test "name the client's stat, with no invisible character and nothing escaped" do
    html = weapons()

    assert html =~ ">Critical</th>"
    refute html =~ " "
    # Escaped, it would print the five characters on the page.
    refute html =~ "&amp;nbsp;"
  end
end
