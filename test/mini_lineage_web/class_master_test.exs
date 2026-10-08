defmodule MiniLineageWeb.ClassMasterTest do
  @moduledoc """
  Every calling stands where the run stands on the day it is taken, so the Class Master shows what
  each one adds per level from there, never what each would be by the last level.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias MiniLineage.Game.{Constants, Math, Player, Snapshot}

  defp html_at(level) do
    {player, _} = Player.initialize(%Player{}, Constants.race(0), :fighter, "Hero")
    player = %{player | experience: Math.xp_for_level(level), current_screen: "class_master"}

    render_component(&MiniLineageWeb.Screens.screen/1,
      view: Snapshot.build(player),
      screen: "class_master",
      catalog: Snapshot.catalog()
    )
  end

  defp row(html, id),
    do: html |> LazyHTML.from_fragment() |> LazyHTML.query("#calling-#{id}") |> LazyHTML.text()

  test "shows what each calling adds per level, worked from the run's own CON and MEN" do
    # The Warrior's 33.0 and the Knight's 29.7 a level, × 1.58 for a Human Fighter's CON 43.
    html = html_at(20)

    assert row(html, 1) =~ "Warrior" and row(html, 1) =~ "+52"
    assert row(html, 4) =~ "Human Knight" and row(html, 4) =~ "+47"
    assert html =~ "HP per Level"
    refute html =~ "at 80"
  end

  test "below the calling's level, offers it closed, and says what it will add once taken" do
    html = html_at(5)

    assert html =~ "opens at"
    assert row(html, 1) =~ "+52"
    assert length(Regex.scan(~r/<option[^>]*disabled/, html)) == 3
  end
end
