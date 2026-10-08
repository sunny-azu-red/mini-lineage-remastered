defmodule MiniLineage.Game.FormulasTest do
  @moduledoc """
  Interlude's formulas against numbers worked by hand from L2J Mobius CT_0, so a formula that drifts
  names the stat it broke. The rolls are tested with the source pinned, never on a live draw.
  """
  use ExUnit.Case, async: true

  alias MiniLineage.Game.{Formulas, Rng}

  # `statBonus.xml`, values 0 to 99 for each attribute.
  @bonus "test/fixtures/stat_bonus.json" |> File.read!() |> Jason.decode!()

  defp pin(value), do: Rng.put_source(fn -> value end)

  describe "an attribute's bonus" do
    test "is the datapack's table at every value from 1 to 99" do
      for {attr, table} <- @bonus, value <- 1..99 do
        assert Formulas.bonus(String.to_existing_atom(attr), value) == Enum.at(table, value),
               "#{attr} #{value}"
      end
    end

    test "and the level modifier is (level + 89) / 100" do
      assert Formulas.level_mod(1) == 0.9
      assert Formulas.level_mod(80) == 1.69
    end
  end

  describe "the derived stats" do
    test "a Human Fighter's at level 1, worked by hand" do
      # STR 40 is 1.20, CON 43 is 1.58, DEX 30 is 1.10, MEN 25 is 1.28; level 1 is 0.90.
      assert_in_delta Formulas.p_atk(4, 40, 1), 4 * 1.20 * 0.9, 1.0e-9
      assert_in_delta Formulas.p_def(80, 1), 72.0, 1.0e-9
      assert_in_delta Formulas.m_def(41, 25, 1), 41 * 1.28 * 0.9, 1.0e-9
      assert Formulas.max_hp(80.0, 43) == 126
      assert Formulas.max_mp(30.0, 25) == 38
      assert Formulas.crit_rate(4, 30) == 44
      assert Formulas.accuracy(30, 1) == 34
      assert Formulas.evasion(30, 1) == 34
      assert Formulas.p_atk_spd(300, 30) == 330
    end

    test "M.Atk squares both INT and the level" do
      # A Human Mystic: INT 41 is 1.21.
      assert_in_delta Formulas.m_atk(6, 41, 1), 6 * 1.21 * 1.21 * 0.9 * 0.9, 1.0e-9
      assert_in_delta Formulas.m_atk(6, 41, 80), 6 * 1.21 * 1.21 * 1.69 * 1.69, 1.0e-9
    end

    test "accuracy and evasion each take their own extra past level 69" do
      # √30 × 6 + 80 = 112.86; accuracy adds 11 and 4, evasion 11 × 1.2.
      assert Formulas.accuracy(30, 80) == 128
      assert Formulas.evasion(30, 80) == 126
      assert Formulas.accuracy(30, 69) == Formulas.evasion(30, 69)
    end

    test "magic critical moves only in whole steps of WIT's bonus" do
      assert Formulas.m_crit_rate(1, 11) == 0
      assert Formulas.m_crit_rate(1, 20) == 10
      assert Formulas.m_crit_rate(1, 40) == 20
    end

    test "every capped stat stops at Interlude's cap" do
      assert Formulas.crit_rate(100, 99) == 500
      assert Formulas.m_crit_rate(1, 99) == 200
      assert Formulas.p_atk_spd(3_000, 99) == 1500
      assert Formulas.m_atk_spd(3_000, 99) == 1999
    end

    test "regeneration never falls under 1 before posture, and sitting is half again" do
      # MP at level 1 with MEN 25: 0.9 × 0.90 × 1.28 = 1.04.
      assert_in_delta Formulas.mp_regen(0.9, 25, 1, :standing), 1.0368 * 1.1, 1.0e-9
      assert Formulas.hp_regen(0.1, 1, 1, :sitting) == 1.5
      assert_in_delta Formulas.hp_regen(2.0, 43, 1, :running), 2.0 * 0.9 * 1.58 * 0.7, 1.0e-9
    end
  end

  describe "a blow" do
    test "lands 80% of the time at even odds, more from behind, and never outside 20% to 98%" do
      assert Formulas.hit_chance(50, 50, :front) == 800
      assert Formulas.hit_chance(50, 50, :side) == 840
      assert Formulas.hit_chance(50, 50, :behind) == 880
      assert Formulas.hit_chance(90, 50, :front) == 980
      assert Formulas.hit_chance(10, 90, :behind) == 200
    end

    test "hits for 76 × P.Atk ÷ P.Def, more from the side and behind, double on a critical" do
      assert Formulas.physical_damage(100, 76, []) == 100.0
      assert_in_delta Formulas.physical_damage(100, 76, position: :side), 110.0, 1.0e-9
      assert_in_delta Formulas.physical_damage(100, 76, position: :behind), 120.0, 1.0e-9
      assert Formulas.physical_damage(100, 76, crit: true) == 200.0
      assert_in_delta Formulas.physical_damage(100, 76, variance: 0.9), 90.0, 1.0e-9
    end

    test "never does less than 1 once it lands at all" do
      assert Formulas.physical_damage(1, 10_000, []) == 1.0
    end
  end

  describe "a spell" do
    test "hits for 91 × √M.Atk ÷ M.Def × power, three times over on a critical" do
      assert_in_delta Formulas.magic_damage(100, 91, 10), 100.0, 1.0e-9
      assert_in_delta Formulas.magic_damage(400, 91, 10), 200.0, 1.0e-9
      assert_in_delta Formulas.magic_damage(100, 91, 10, crit: true), 300.0, 1.0e-9
    end

    test "is resisted more the further the target stands above the caster" do
      assert Formulas.magic_success_rate(20, 20) == 99
      assert Formulas.magic_success_rate(20, 30) == 86
    end

    test "lands an effect against the target's saving attribute, inside the skill's bounds" do
      effect = %{
        magic_level: 20,
        target_level: 20,
        level_bonus_rate: 2,
        activate_rate: 50,
        target_stat: 30,
        min: 10,
        max: 90
      }

      assert Formulas.effect_chance(effect) == 56
      assert Formulas.effect_chance(%{effect | target_stat: 45}) == 41
      assert Formulas.effect_chance(%{effect | target_stat: 99}) == 10
      assert Formulas.effect_chance(Map.merge(effect, %{m_atk: 400, m_def: 110})) == 90
    end
  end

  describe "experience" do
    test "is paid only within ten levels either way, with no decay inside that" do
      assert Formulas.exp_share(30, 20) == 1.0
      assert Formulas.exp_share(31, 20) == 0.0
      assert Formulas.exp_share(20, 30) == 1.0
    end

    test "an overhit adds its share of the monster's HP, up to a quarter more" do
      assert Formulas.overhit_exp(1_000, 100, 1_000) == 100.0
      assert Formulas.overhit_exp(1_000, 900, 1_000) == 250.0
    end
  end

  describe "the rolls, with the source pinned" do
    test "a critical needs the rate to beat the draw, a hit only to meet it" do
      pin(0.5)

      assert Formulas.crit?(501)
      refute Formulas.crit?(500)
      assert Formulas.hit?(500)
      refute Formulas.hit?(499)
    end

    test "the position runs front, side, behind across the draw" do
      pin(0.0)
      assert Formulas.random_position() == :front
      pin(0.5)
      assert Formulas.random_position() == :side
      pin(0.99)
      assert Formulas.random_position() == :behind
    end

    test "the spread runs from -range% to +range%, and bare hands take theirs from the level" do
      pin(0.0)
      assert Formulas.damage_variance(10) == 0.9
      pin(0.9999)
      assert Formulas.damage_variance(10) == 1.1
      assert Formulas.unarmed_range(1) == 6
      assert Formulas.unarmed_range(80) == 13
    end
  end
end
