defmodule MiniLineage.Game.ProgressionTest do
  @moduledoc """
  The derived numbers a player reads off the sidebar and the Character screen: the level curve, the
  XP bar, the HP bar, and the stat pipeline that feeds them.

  The golden master pins nine integers after 400 fights, which catches a change in the arithmetic
  but says nothing about its shape. These state the properties directly, across the whole curve and
  every gear tier, so a break names itself instead of surfacing as one shifted total.
  """
  use ExUnit.Case, async: true

  alias MiniLineage.Game.{Constants, Math, Player, Snapshot}

  @max Constants.max_level()

  defp player(opts \\ []) do
    race = Constants.race(Keyword.get(opts, :race_id, 0))

    %Player{
      name: "Hero",
      race_id: race.id,
      health: Keyword.get(opts, :health, race.start_health),
      adena: race.start_adena,
      experience: Keyword.get(opts, :experience, 0),
      weapon_id: Keyword.get(opts, :weapon_id, 0),
      armor_id: Keyword.get(opts, :armor_id, 0),
      effects: Keyword.get(opts, :effects, [])
    }
  end

  describe "the level curve" do
    test "climbs strictly, so no two levels ever share a threshold" do
      thresholds = Enum.map(1..@max, &Math.xp_for_level/1)

      assert thresholds == Enum.sort(thresholds)
      assert length(Enum.uniq(thresholds)) == length(thresholds)
    end

    test "level_for_xp inverts xp_for_level at every boundary" do
      for level <- 1..@max do
        at = Math.xp_for_level(level)

        assert Math.level_for_xp(at) == level, "exactly #{at} XP should be level #{level}"

        if level > 1 do
          assert Math.level_for_xp(at - 1) == level - 1,
                 "one XP short of #{at} should still be level #{level - 1}"
        end
      end
    end

    test "level 1 starts at zero, and nothing below it exists" do
      assert Math.xp_for_level(1) == 0
      assert Math.level_for_xp(0) == 1
    end

    test "the cap holds however much experience is piled on top of it" do
      beyond = Math.xp_for_level(@max) * 10

      assert Math.level_for_xp(beyond) == @max
      assert Math.max_level?(Math.level_for_xp(beyond))
    end
  end

  describe "the XP bar" do
    test "reads empty at every level boundary and full nowhere below the next one" do
      for level <- 1..(@max - 1) do
        at = Math.xp_for_level(level)
        progress = Math.xp_progress(at)

        assert progress.current == 0
        assert progress.percent == 0
        assert progress.required == Math.xp_for_level(level + 1) - at
      end
    end

    test "never leaves the bar, wherever in a level the character stands" do
      for level <- 1..(@max - 1), step <- [0, 1, 3, 7] do
        span = Math.xp_for_level(level + 1) - Math.xp_for_level(level)
        xp = Math.xp_for_level(level) + div(span * step, 8)
        progress = Math.xp_progress(xp)

        assert progress.percent >= 0 and progress.percent <= 100
        assert progress.current >= 0 and progress.current <= progress.required
      end
    end

    test "what remains to the next level closes to nothing exactly as it arrives" do
      for level <- 1..(@max - 1) do
        next = Math.xp_for_level(level + 1)

        assert Math.xp_needed_to_level_up(next - 1) == 1

        # Arriving at a level restarts the count toward the one after it — unless that arrival is
        # the cap, where nothing remains to earn.
        if level + 1 < @max do
          assert Math.xp_needed_to_level_up(next) == Math.xp_for_level(level + 2) - next
        else
          assert Math.xp_needed_to_level_up(next) == 0
        end
      end
    end

    test "at the cap there is nothing left to earn, and the bar stands full" do
      at_cap = Math.xp_for_level(@max)

      assert Math.xp_needed_to_level_up(at_cap) == 0
      assert Math.xp_progress(at_cap) == %{current: 0, required: 0, percent: 100}
    end
  end

  describe "the HP bar" do
    test "is a percentage of the effective maximum, and stays inside it" do
      view = Snapshot.build(player(health: 50))

      assert view.hp_percent == Math.percentage(50, view.max_health)
      assert view.hp_percent >= 0 and view.hp_percent <= 100
    end

    test "reads empty at death and full at the top, for every race" do
      for race_id <- 0..3 do
        max = Snapshot.build(player(race_id: race_id)).max_health

        assert Snapshot.build(player(race_id: race_id, health: 0)).hp_percent == 0
        assert Snapshot.build(player(race_id: race_id, health: max)).hp_percent == 100
      end
    end

    test "a total of zero is nought percent rather than a division by zero" do
      assert Math.percentage(5, 0) == 0
    end
  end

  describe "the stat pipeline" do
    test "each gear tier is a strict improvement on the one below it" do
      attacks = Enum.map(0..5, &Player.stats(player(weapon_id: &1)).attack)
      defenses = Enum.map(0..5, &Player.stats(player(armor_id: &1)).defense)

      assert attacks == Enum.sort(attacks)
      assert defenses == Enum.sort(defenses)
      assert Enum.uniq(attacks) == attacks
      assert Enum.uniq(defenses) == defenses
    end

    test "gear adds to the race's own numbers rather than replacing them" do
      for race_id <- 0..3 do
        bare = Player.stats(player(race_id: race_id))
        armed = Player.stats(player(race_id: race_id, weapon_id: 5, armor_id: 5))

        assert armed.attack == Constants.weapon(5).stat
        assert armed.defense == Constants.armor(5).stat
        # Innate traits survive the upgrade; only the equipment figures move.
        assert armed.max_health == bare.max_health
      end
    end

    test "a buff adds its modifiers, and expires back to where it started" do
      before = Player.stats(player())
      buffed = Player.apply_effect(player(), Constants.effect(:newbie_buff))
      after_buff = Player.stats(buffed)

      assert after_buff.max_health == before.max_health + 20
      assert after_buff.defense == before.defense + 2
      assert after_buff.ambush_risk == before.ambush_risk - 4
      assert Player.stats(%{buffed | effects: []}) == before
    end

    test "no stat can be driven out of its own range" do
      # A debuff far larger than any real one: the clamps, not the balance, are what is under test.
      crushing = %{
        id: "test_crush",
        type: :debuff,
        emoji: "🧪",
        label: "Crushed",
        modifiers: [
          %{type: :attack, value: -9_999},
          %{type: :defense, value: -9_999},
          %{type: :crit, value: -9_999},
          %{type: :regen, value: -9_999},
          %{type: :max_health, value: -9_999},
          %{type: :ambush_risk, value: -9_999},
          %{type: :xp_multiplier, value: 0},
          %{type: :adena_multiplier, value: 0}
        ]
      }

      stats = Player.stats(Player.apply_effect(player(weapon_id: 5, armor_id: 5), crushing))

      assert stats.attack == 0
      assert stats.defense == 0
      assert stats.crit == 0
      assert stats.regen == 0
      assert stats.ambush_risk == 0
      assert stats.max_health == 1, "a maximum of zero would make the HP bar undividable"
      assert stats.xp_multiplier == 0
      assert stats.adena_multiplier == 0
    end

    test "crit and ambush risk cannot be pushed above a whole certainty" do
      soaring = %{
        id: "test_soar",
        type: :buff,
        emoji: "🧪",
        label: "Soaring",
        modifiers: [%{type: :crit, value: 9_999}, %{type: :ambush_risk, value: 9_999}]
      }

      stats = Player.stats(Player.apply_effect(player(), soaring))

      assert stats.crit == 100
      assert stats.ambush_risk == 100
    end
  end
end
