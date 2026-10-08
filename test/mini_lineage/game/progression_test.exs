defmodule MiniLineage.Game.ProgressionTest do
  @moduledoc """
  The derived numbers a player reads off the sidebar and the Character screen: the level curve, the
  XP bar, the HP bar, and the stat pipeline that feeds them.

  The golden master catches a change in the arithmetic but not its shape. These state the
  properties across the whole curve and every gear tier, so a break names itself.
  """
  use ExUnit.Case, async: true

  alias MiniLineage.Game.{Battle, Classes, Constants, Formulas, Math, Player, Rng}

  @max Constants.max_level()

  defp player(opts \\ []) do
    race = Constants.race(Keyword.get(opts, :race_id, 0))

    %Player{
      name: "Hero",
      race_id: race.id,
      health: Keyword.get(opts, :health, 100),
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

    test "is Interlude's table divided down, rounded up" do
      # 68, 48,229 and 4,200,000,000 EXP in Interlude for levels 2, 10 and 80.
      assert Math.xp_for_level(2) == 1
      assert Math.xp_for_level(10) == 161
      assert Math.xp_for_level(80) == 14_000_000
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

  describe "a percentage" do
    test "stays inside 0 to 100" do
      assert Math.percentage(-5, 10) == 0
      assert Math.percentage(15, 10) == 100
    end

    test "of a total of zero is nought rather than a division by zero" do
      assert Math.percentage(5, 0) == 0
    end
  end

  describe "the stat pipeline" do
    test "each gear tier is a strict improvement on the one below it" do
      attacks = Enum.map(0..5, &Player.stats(player(weapon_id: &1)).p_atk)
      defenses = Enum.map(0..5, &Player.stats(player(armor_id: &1)).p_def)

      assert attacks == Enum.sort(attacks)
      assert defenses == Enum.sort(defenses)
      assert Enum.uniq(attacks) == attacks
      assert Enum.uniq(defenses) == defenses
    end

    test "gear stands in for the class's bare hands and naked slots, nothing else" do
      for race_id <- 0..3 do
        bare = Player.stats(player(race_id: race_id))
        armed = Player.stats(player(race_id: race_id, weapon_id: 5, armor_id: 5))
        class = Classes.starting(race_id, :fighter)

        assert armed.p_atk == Formulas.p_atk(Constants.weapon(5).stat, class.attributes.str, 1)

        assert armed.p_def ==
                 Formulas.p_def(Classes.bases(class.id).p_def + Constants.armor(5).stat, 1)

        # What the class was born with survives the upgrade; only the equipment figures move.
        assert armed.max_hp == bare.max_hp

        assert Map.take(armed, ~w(str con dex int wit men)a) ==
                 Map.take(bare, ~w(str con dex int wit men)a)
      end
    end

    test "every level raises what the class derives from it" do
      low = Player.stats(player())
      high = Player.stats(player(experience: Math.xp_for_level(40)))

      for key <- ~w(p_atk m_atk p_def m_def accuracy evasion max_hp max_mp hp_regen mp_regen)a do
        assert high[key] > low[key], "#{key} did not grow from level 1 to 40"
      end
    end

    test "a buff adds its modifiers, and expires back to where it started" do
      before = Player.stats(player())
      buffed = Player.apply_effect(player(), Constants.effect(:newbie_buff))
      after_buff = Player.stats(buffed)

      assert after_buff.max_hp == before.max_hp + 20
      assert after_buff.p_def == before.p_def + 2
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
          %{type: :p_atk, value: -9_999},
          %{type: :p_def, value: -9_999},
          %{type: :crit_rate, value: -9_999},
          %{type: :hp_regen, value: -9_999},
          %{type: :max_hp, value: -9_999},
          %{type: :ambush_risk, value: -9_999},
          %{type: :xp_multiplier, op: :mul, value: 0},
          %{type: :adena_multiplier, op: :mul, value: 0}
        ]
      }

      stats = Player.stats(Player.apply_effect(player(weapon_id: 5, armor_id: 5), crushing))

      assert stats.p_atk == 0
      assert stats.p_def == 0
      assert stats.crit_rate == 0
      assert stats.hp_regen == 0
      assert stats.ambush_risk == 0
      assert stats.max_hp == 1, "a maximum of zero would make the HP bar undividable"
      assert stats.xp_multiplier == 0
      assert stats.adena_multiplier == 0
    end

    test "what an effect adds still stops at Interlude's caps, and ambush risk at a certainty" do
      soaring = %{
        id: "test_soar",
        type: :buff,
        emoji: "🧪",
        label: "Soaring",
        modifiers:
          Enum.map(
            ~w(crit_rate m_crit_rate evasion p_atk_spd m_atk_spd ambush_risk)a,
            &%{type: &1, value: 9_999}
          )
      }

      stats = Player.stats(Player.apply_effect(player(), soaring))

      assert stats.crit_rate == 500
      assert stats.m_crit_rate == 200
      assert stats.evasion == 250
      assert stats.p_atk_spd == 1500
      assert stats.m_atk_spd == 1999
      assert stats.ambush_risk == 100
    end
  end

  describe "the battle bridge" do
    # Until the fight is rebuilt on `Formulas`, a bar that grows with the level must not make the
    # road harmless: the same dice cost the same share of it at any level.
    test "costs the same share of the HP bar at level 40 as at level 1" do
      share = fn player ->
        Rng.put_source(fn -> 0.5 end)
        Battle.simulate(player).hp_lost / Player.stats(player).max_hp
      end

      assert_in_delta share.(player()), share.(player(experience: Math.xp_for_level(40))), 0.01
    end
  end
end
