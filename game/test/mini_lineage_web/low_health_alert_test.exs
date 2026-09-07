defmodule MiniLineageWeb.LowHealthAlertTest do
  @moduledoc "When the low-health warning appears, and the two screens that suppress it."
  use ExUnit.Case, async: true

  alias MiniLineage.Game.{Constants, Player, Snapshot}
  alias MiniLineageWeb.Screens

  defp view(overrides \\ %{}) do
    {player, _} = Player.initialize(%Player{}, Constants.race(0), "Wounded")
    Snapshot.build(Map.merge(%{player | health: 5}, overrides))
  end

  test "warns on every screen that shows HP" do
    for screen <- ~w(home battle weapons armors death) do
      assert Screens.low_health_alert?(view(), screen), screen
    end
  end

  test "stays quiet in the Inn, whose own call to action is already the answer" do
    refute Screens.low_health_alert?(view(), "inn")
  end

  test "stays quiet on Suicide, where it would read as encouragement" do
    refute Screens.low_health_alert?(view(), "suicide")
  end

  test "stays quiet where there is no HP on screen at all" do
    for screen <- ~w(character highscores statistics races start error) do
      refute Screens.low_health_alert?(view(), screen), screen
    end
  end

  test "does not warn a healthy character" do
    refute Screens.low_health_alert?(view(%{health: 120}), "home")
  end

  test "does not warn the dead — they are past warning" do
    refute Screens.low_health_alert?(view(%{health: 0, dead: true}), "death")
  end

  test "does not warn a visitor with no character" do
    refute Screens.low_health_alert?(Snapshot.build(%Player{}), "home")
  end
end
