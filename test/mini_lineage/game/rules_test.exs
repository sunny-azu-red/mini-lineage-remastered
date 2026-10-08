defmodule MiniLineage.Game.RulesTest do
  @moduledoc """
  `docs/rules.md` and the code, held together: every table in the document is read back out of it
  and compared with `Rules`, and every worked example is worked again by `Formulas`. Change one
  without the other and this fails.
  """
  use ExUnit.Case, async: true

  alias MiniLineage.Game.{Formulas, Math, Rng, Rules}

  @rules File.read!("docs/rules.md")

  # The rows of the markdown table whose header starts with `first`, as lists of trimmed cells.
  defp table(first) do
    [_, body] = String.split(@rules, "| #{first} |", parts: 2)

    body
    |> String.split("\n")
    |> Enum.drop(2)
    |> Enum.take_while(&String.starts_with?(&1, "|"))
    |> Enum.map(fn row -> row |> String.split("|", trim: true) |> Enum.map(&String.trim/1) end)
  end

  defp number(cell), do: cell |> String.replace(",", "") |> Float.parse() |> elem(0)

  @paths %{"Fighter" => :fighter, "Mystic" => :mystic}
  @races %{"Human" => 0, "Orc" => 1, "Elf" => 2, "Dark Elf" => 3}

  describe "the tables" do
    test "§3 starting attributes are the eight sets the code starts from" do
      rows = table("Set")
      assert length(rows) == 8

      for [name, race, path | values] <- rows do
        set = Rules.set(@races[race], @paths[path])
        assert set.name == name

        assert Enum.map(values, &String.to_integer/1) ==
                 Enum.map(~w(str con dex int wit men)a, &set.attributes[&1]),
               name
      end
    end

    test "§4 the attribute curves, and the bonus each is worth at 20, 30, 40 and 50" do
      for [attr, growth, pivot | samples] <- table("Attribute"), samples != [] do
        key = attr |> String.downcase() |> String.to_existing_atom()
        assert Rules.bonus_curve(key) == {number(growth), number(pivot)}, attr

        for {value, sample} <- Enum.zip([20, 30, 40, 50], samples),
            do: assert(Formulas.bonus(key, value) == number(sample), "#{attr} #{value}")
      end
    end

    test "§6 every set's HP and MP start, gain and growth" do
      rows = table("Set | HP start")
      assert length(rows) == 8

      for [name | values] <- rows do
        set = Enum.find(Rules.sets(), &(&1.name == name))
        [hs, hg, hgr, ms, mg, mgr] = Enum.map(values, &number/1)

        assert set.hp == {hs, hg, hgr}, name
        assert set.mp == {ms, mg, mgr}, name
      end
    end

    test "§7 what each path starts with" do
      for [path, power, magic, body, mind] <- table("Path") do
        assert Rules.path(@paths[path]) ==
                 %{
                   power: trunc(number(power)),
                   magic: trunc(number(magic)),
                   body: trunc(number(body)),
                   mind: trunc(number(mind))
                 },
               path
      end
    end

    test "§12 the EXP for every level, 1 to 80" do
      written =
        table("Levels")
        |> Enum.flat_map(fn [_, values] -> String.split(values, ", ") end)
        |> Enum.map(&String.to_integer/1)

      assert written == Enum.map(1..80, &Rules.experience/1)
      assert Rules.max_level() == 80
      assert Enum.map(1..80, &Math.xp_for_level/1) == written
    end
  end

  describe "the worked examples" do
    setup do
      %{hf: Rules.set(0, :fighter), hm: Rules.set(0, :mystic)}
    end

    test "§4 and §5", %{hf: hf} do
      assert Formulas.bonus(:str, hf.attributes.str) == 1.20
      assert Formulas.level_bonus(1) == 0.90
      assert Formulas.level_bonus(80) == 1.69
    end

    test "§6 a Human Fighter's Max HP at 1, 20, 40 and 80", %{hf: hf} do
      hp = fn level -> Formulas.max_hp(Formulas.grown(hf.hp, level), hf.attributes.con) end

      assert Formulas.grown(hf.hp, 20) == 327
      assert Enum.map([1, 20, 40, 80], hp) == [126, 516, 1007, 2235]
    end

    test "§7 power, at level 1", %{hf: hf, hm: hm} do
      fighter = Rules.path(:fighter)

      assert_in_delta Formulas.p_atk(fighter.power, hf.attributes.str, 1), 4.32, 1.0e-9
      assert_in_delta Formulas.p_def(fighter.body, 1), 72.0, 1.0e-9
      assert_in_delta Formulas.m_def(fighter.mind, hf.attributes.men, 1), 47.2, 0.05
      assert_in_delta Formulas.m_atk(Rules.path(:mystic).magic, hm.attributes.int, 1), 7.1, 0.05
    end

    test "§8 Accuracy and Evasion", %{hf: hf} do
      assert Formulas.accuracy(hf.attributes.dex, 1) == 34
      assert Formulas.evasion(hf.attributes.dex, 1) == 34
    end

    test "§9 Critical and Magic Critical, and their caps", %{hf: hf, hm: hm} do
      assert_in_delta Formulas.critical(hf.attributes.dex), 4.4, 1.0e-9
      assert_in_delta Formulas.magic_critical(hm.attributes.wit), 0.8, 1.0e-9
      # DEX alone never reaches the 50% cap; what an effect adds is held to it in `Player`.
      assert Formulas.caps().critical == 50
      assert Formulas.magic_critical(99) == 20
    end

    test "§10 speed, blows a round, and the caps", %{hf: hf} do
      assert Formulas.atk_spd(hf.attributes.dex) == 330
      assert_in_delta Formulas.blows_per_round(330), 1.1, 1.0e-9
      assert Formulas.casts_per_round(333) == 1.0
      assert Formulas.atk_spd(99) <= 1500
      assert Formulas.cast_spd(99) == 1999
    end

    test "§11 resting: a minute to full at level 1, a minute and a half at 40", %{hf: hf} do
      con = hf.attributes.con
      assert_in_delta Formulas.hp_regen(1, con), 6.6, 0.05
      assert_in_delta Formulas.hp_regen(40, con), 33.0, 0.05

      ticks = fn level, max -> ceil(max / Formulas.hp_regen(level, con)) end
      assert (ticks.(1, 126) * 3) in 55..65
      assert (ticks.(40, 1007) * 3) in 85..100
    end

    test "§13 hit chance, inside 28% and 98%" do
      assert Formulas.hit_chance(40, 34) == 98
      assert Formulas.hit_chance(34, 34) == 88
      assert Formulas.hit_chance(0, 100) == 28
    end

    test "§13 damage, physical and magic, with their criticals" do
      assert Formulas.physical_damage(100, 70) == 100.0
      assert Formulas.physical_damage(100, 70, critical: true) == 200.0
      assert_in_delta Formulas.physical_damage(100, 70, spread: 0.9), 90.0, 1.0e-9
      assert Formulas.physical_damage(1, 10_000) == 1.0

      assert_in_delta Formulas.magic_damage(100, 91, 10), 100.0, 1.0e-9
      assert_in_delta Formulas.magic_damage(100, 91, 10, critical: true), 400.0, 1.0e-9
    end

    test "§13 the rolls, with the source pinned" do
      Rng.put_source(fn -> 0.0 end)
      assert Formulas.damage_spread() == 0.9
      Rng.put_source(fn -> 0.9999 end)
      assert Formulas.damage_spread() == 1.1
      refute Formulas.hit?(50)
      assert Formulas.hit?(100)
    end
  end
end
