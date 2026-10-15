defmodule MiniLineage.Game.SnapshotTest do
  @moduledoc "The Player -> view mapping, and the catalog the pages draw from."
  use ExUnit.Case, async: true

  alias MiniLineage.Game.{Clock, Constants, Math, Player, Rules, Snapshot}

  defp character(race_id \\ 0, overrides \\ %{}) do
    {player, _} = Player.initialize(%Player{}, Constants.race(race_id), :fighter, "Subject")
    Map.merge(player, overrides)
  end

  test "a character that does not exist has EVERY key one that does has" do
    # A screen still rendering as a character is reset must draw, not raise and remount silently.
    started = Snapshot.build(character())
    empty = Snapshot.build(%Player{})

    assert Map.keys(empty) == Map.keys(started)
    refute empty.started
    assert empty.effects == []
  end

  test "a character stands in its own race's village" do
    for race <- Constants.races() do
      town = Snapshot.build(character(race.id)).town

      assert town.name == Rules.town(Rules.hometown(race.id)).name
      assert town.description == Constants.town_description(Rules.hometown(race.id))
    end
  end

  describe "the catalog" do
    test "names each race's town and two starting classes, with what they are born with" do
      [human | _] = Snapshot.catalog().races

      assert human.town.name == "Talking Island Village"

      assert [
               %{name: "Human Fighter", path: :fighter, max_hp: 126, max_mp: 38},
               %{name: "Human Mystic", path: :mystic, max_hp: 98, max_mp: 59}
             ] = human.classes
    end

    test "and the same map every time it is asked" do
      assert Snapshot.catalog() == Snapshot.catalog()
    end
  end

  describe "at the top of the curve" do
    test "level 80 reports itself as the end of the road" do
      view = Snapshot.build(character(0, %{experience: Math.xp_for_level(80)}))

      assert view.level == 80
      assert view.is_max_level
      assert view.xp_required == 0
      assert view.xp_current == 0
    end

    test "and one step below it does not" do
      view = Snapshot.build(character(0, %{experience: Math.xp_for_level(79)}))

      assert view.level == 79
      refute view.is_max_level
      assert view.xp_required > 0
    end
  end

  test "a countdown keeps its key from build to build, whatever the clock says, and a new one gets its own" do
    now = ~U[2026-10-15 12:00:00.000Z]
    fades = DateTime.to_unix(now, :millisecond) + 60_000
    player = character(2, %{buffs: %{"Defense Aura" => fades}})
    aura = fn player -> Enum.find(Snapshot.build(player).effects, &(&1.id == "defense_aura")) end

    Clock.put_now(now)
    first = aura.(player)
    # A stepped clock: the duration moves, the countdown it names does not.
    Clock.put_now(DateTime.add(now, 3_600, :millisecond))
    later = aura.(player)

    assert {first.remaining_ms, later.remaining_ms} == {60_000, 56_400}
    assert first.timer_key == later.timer_key

    refute aura.(%{player | buffs: %{"Defense Aura" => fades + 60_000}}).timer_key ==
             first.timer_key

    assert Enum.all?(Snapshot.build(character()).effects, &(&1.timer_key == nil))
  end

  test "the regenerating tooltip says what a tick restores" do
    view = Snapshot.build(character(0, %{health: 10, mp: 0}))
    regenerating = Enum.find(view.effects, &(&1.id == "regenerating"))

    assert regenerating.tooltip == "Regenerating (+7 HP, +3 MP)"
  end
end
