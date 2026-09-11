defmodule MiniLineageWeb.LowHealthAlertTest do
  @moduledoc "When the low-health warning appears, and the two screens that suppress it."
  use ExUnit.Case, async: true

  alias MiniLineage.Game.{Constants, Player, Snapshot}
  alias MiniLineageWeb.Screens

  defp view(overrides \\ %{}) do
    {player, _} = Player.initialize(%Player{}, Constants.race(0), "Wounded")
    Snapshot.build(Map.merge(%{player | health: 5}, overrides))
  end

  describe "the line shown while ambushed" do
    alias MiniLineage.Game.{Narrative, Narratives}

    defp player(overrides) do
      {p, _} = Player.initialize(%Player{}, Constants.race(1), "Hero")
      Map.merge(p, overrides)
    end

    test "is drawn from the pool, not fixed to the head of it" do
      lines =
        for a <- 0..30,
            do: Narrative.ambush_low_health(player(%{total_ambushes: a, experience: a * 137}))

      assert Enum.all?(lines, &(&1 in Narratives.ambush_low_health()))
      assert length(Enum.uniq(lines)) > 1, "every ambush shows the same warning"
    end

    test "and holds still while the player bleeds out" do
      # The banner re-renders on every tick. A fresh roll each time would flicker through nine
      # lines while the player is reading it.
      base = player(%{total_ambushes: 3, experience: 900})

      lines =
        for h <- [40, 30, 20, 10, 5, 1], do: Narrative.ambush_low_health(%{base | health: h})

      assert length(Enum.uniq(lines)) == 1, "the warning changed as health fell"
    end

    test "and reaches the alert rather than a compile-time constant" do
      view = view(%{ambushed: true, total_ambushes: 3, experience: 900})

      assert view.ambush_low_health in Narratives.ambush_low_health()
    end
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
