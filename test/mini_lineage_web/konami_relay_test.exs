defmodule MiniLineageWeb.KonamiRelayTest do
  @moduledoc """
  The relay sends every keypress to the server, so it is on the page only for a run the sequence
  can do something to: started, alive, and not already marked. Anywhere else each key was a round
  trip that ended in a no-op.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias MiniLineage.Game.{Actions, Constants, Player, Snapshot}

  defp page_for(player, screen \\ "home") do
    render_component(&MiniLineageWeb.Layouts.app/1,
      title: "Home Town",
      view: Snapshot.build(player),
      screen: screen,
      inner_block: [%{inner_block: fn _, _ -> "" end, __slot__: :inner_block}]
    )
  end

  defp relays?(html), do: html =~ ~s(phx-hook="KonamiRelay")

  defp living do
    {player, _} = Player.initialize(%Player{}, Constants.race(0), "Hero")
    player
  end

  test "listens for a living run" do
    assert relays?(page_for(living()))
  end

  test "but not for a visitor on Game Start" do
    refute relays?(page_for(%Player{}, "start"))
  end

  test "nor for the dead" do
    refute relays?(page_for(%{Player.kill(living()) | death_reason: "x"}, "death"))
  end

  test "nor for a run already marked, which the sequence cannot mark twice" do
    {cheated, _} = Actions.cheat(living())

    refute relays?(page_for(cheated))
  end
end
