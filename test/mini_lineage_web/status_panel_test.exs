defmodule MiniLineageWeb.StatusPanelTest do
  @moduledoc """
  The sidebar the town carries. Its figures animate, so each is its own element, and HEEx renders
  a newline between elements as a space, which this reads through.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias MiniLineage.Game.{Constants, Math, Player, Snapshot}

  defp sidebar_for(player) do
    render_component(&MiniLineageWeb.Layouts.app/1,
      panels: [%{title: "Dark Elven Village", icon: nil}],
      view: Snapshot.build(player),
      screen: "town",
      inner_block: [%{inner_block: fn _, _ -> "" end, __slot__: :inner_block}]
    )
  end

  defp text(html), do: html |> String.replace(~r/<[^>]+>/, "") |> String.replace(~r/\s+/, " ")

  setup do
    {player, _} = Player.initialize(%Player{}, Constants.race(3), :fighter, "Sunny")

    %{html: sidebar_for(%{player | experience: Math.xp_for_level(5)})}
  end

  test "is headed with the class, and puts the level against the name", %{html: html} do
    assert text(html) =~ "🧛 Dark Fighter 5 Sunny HP 107"
  end

  test "and leaves no space in front of any punctuation", %{html: html} do
    assert Regex.scan(~r/\S+ [,.]/, text(html)) == [], text(html)
  end

  test "every figure it shows is one the hook can count", %{html: html} do
    keys = Regex.scan(~r/data-key="([^"]+)"/, html) |> Enum.map(&List.last/1)

    assert Enum.sort(keys) == Enum.sort(~w(adena hp level max-hp max-mp mp xp-percent))
  end

  test "a new character's purse holds nothing", %{html: _html} do
    {player, _} = Player.initialize(%Player{}, Constants.race(0), :mystic, "Sunny")

    assert sidebar_for(player) =~ ~r|data-key="adena"[^>]*>0</span>|
  end
end
