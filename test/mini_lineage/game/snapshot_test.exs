defmodule MiniLineage.Game.SnapshotTest do
  @moduledoc """
  The Player -> view mapping, including the states the cross-stack audit could not reach because
  they need particular rolls: max level, low health, and a character that no longer exists.
  """
  use ExUnit.Case, async: true

  alias MiniLineage.Game.{Constants, Format, Math, Narrative, Player, Snapshot}

  defp character(race_id \\ 0, overrides \\ %{}) do
    {player, _} = Player.initialize(%Player{}, Constants.race(race_id), "Subject")
    Map.merge(player, overrides)
  end

  test "a character that does not exist has EVERY key one that does has" do
    # The absence of this invariant meant a screen still rendering when a character was reset
    # raised instead of drawing, and the LiveView remounted without a word.
    started = Snapshot.build(character())
    empty = Snapshot.build(%Player{})

    assert Map.keys(empty) == Map.keys(started)
    refute empty.started
    assert empty.effects == []
    assert empty.last_battle == nil
    assert empty.counters.total_battles == 0
  end

  describe "the catalog" do
    # Built once per VM and kept in :persistent_term, so a field that is not in fact constant would
    # be frozen at whatever it was on the first mount and never noticed again.
    test "is what building it from the constants would give you" do
      assert Snapshot.catalog() == %{
               races:
                 Enum.map(Constants.races(), fn race ->
                   Map.merge(race, %{
                     slug: Format.slugify(race.label),
                     traits: Narrative.build_race_traits(race)
                   })
                 end),
               weapons: Enum.map(Constants.weapons(), &Snapshot.item_view/1),
               armors: Enum.map(Constants.armors(), &Snapshot.item_view/1),
               foods: Enum.map(Constants.foods(), &Snapshot.item_view/1)
             }
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
      assert view.xp_needed == 0
      assert view.xp_required == 0
      assert view.xp_current == 0
      assert view.xp_percent == 100
    end

    test "and one step below it does not" do
      view = Snapshot.build(character(0, %{experience: Math.xp_for_level(79)}))

      assert view.level == 79
      refute view.is_max_level
      assert view.xp_needed > 0
    end
  end

  describe "low health" do
    test "is a quarter of the effective maximum, not of the race's base" do
      # A Human's base is 100, but the Newbie Blessing lifts the maximum to 120.
      full = Snapshot.build(character())
      threshold = Math.low_health_threshold(full.max_health)

      assert full.max_health == 120
      assert threshold == 30

      refute Snapshot.build(character(0, %{health: threshold + 1})).low_health
      assert Snapshot.build(character(0, %{health: threshold})).low_health
      assert Snapshot.build(character(0, %{health: 1})).low_health
    end

    test "is false at zero, because that is death rather than danger" do
      refute Snapshot.build(character(0, %{health: 0})).low_health
    end
  end

  test "an ambushed character says so, and a dead one carries nothing but the ghost" do
    assert Snapshot.build(character(0, %{ambushed: true})).ambushed

    # `kill/1` empties the effect list; the ghost is derived from being dead rather than carried,
    # and holds no modifiers, so nothing a run had survives it and nothing new is folded in.
    effects = Snapshot.build(Player.kill(character())).effects

    assert [%{id: "ghost", type: :aura, modifiers: []}] = effects
  end

  test "disqualification is derived, never assumed" do
    dead = Player.kill(character())

    refute Snapshot.build(dead).disqualified
    refute Snapshot.build(character()).disqualified, "the living are ranked like anyone else"
    assert Snapshot.build(%{dead | coward: true}).disqualified
    assert Snapshot.build(%{dead | cheated: true}).disqualified
  end

  test "effect tooltips name every modifier, with its unit" do
    view = Snapshot.build(character())
    blessing = Enum.find(view.effects, &(&1.id == "newbie_blessing"))

    assert blessing.tooltip == "Newbie Blessing (+20 Max HP, +2 Defense, -4% Ambush)"
  end

  test "an effect's remaining time is a duration, never a deadline" do
    view = Snapshot.build(character())
    blessing = Enum.find(view.effects, &(&1.id == "newbie_blessing"))

    # A timestamp would force the browser to reconcile two clocks.
    assert blessing.remaining_ms <= 300_000
    assert blessing.remaining_ms > 0
  end

  test "an effect with no duration reports none, rather than zero" do
    {player, _} = Player.sync_zone_auras(%{character() | current_screen: "home"})
    resting = Enum.find(Snapshot.build(player).effects, &(&1.id == "resting"))

    assert resting.remaining_ms == nil, "zero would render as a timer counting nothing down"
  end
end
