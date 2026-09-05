defmodule MiniLineage.Game.JsParityTest do
  @moduledoc """
  Pins the arithmetic and formatting the port cannot verify by inspection: `:math.pow` against
  JavaScript's `Math.pow`, `Math.round`'s halves-toward-+infinity, and `toLocaleString('en-US')`,
  which Elixir has no ICU equivalent for. Every expectation below was produced by running the
  reference expressions in Node, not written by hand.
  """
  use ExUnit.Case, async: true

  alias MiniLineage.Game.{Format, Math}

  @damage_blocked [
    {0, 1},
    {1, 1},
    {2, 1},
    {10, 7},
    {22, 15},
    {41, 27},
    {64, 41},
    {88, 56},
    {150, 93},
    {999, 565}
  ]
  @base_xp [
    {0, 0},
    {1, 0},
    {7, 14},
    {16, 51},
    {28, 118},
    {45, 241},
    {62, 390},
    {90, 683},
    {150, 1469},
    {999, 25260}
  ]
  @base_adena [
    {0, 0},
    {1, 0},
    {7, 8},
    {16, 77},
    {28, 341},
    {45, 1202},
    {62, 2810},
    {90, 7545},
    {150, 29215},
    {999, 4_444_455}
  ]
  @xp_for_level [
    {1, 0},
    {2, 780},
    {3, 1560},
    {10, 14300},
    {25, 84500},
    {50, 331_500},
    {79, 821_600},
    {80, 842_400}
  ]

  @numbers [
    {0, "0"},
    {1, "1"},
    {999, "999"},
    {1000, "1,000"},
    {1234, "1,234"},
    {999_999, "999,999"},
    {1_000_000, "1,000,000"},
    {123_456_789, "123,456,789"},
    {-4567, "-4,567"}
  ]

  @adenas [
    {0, "0"},
    {7, "7"},
    {999, "999"},
    {1000, "1k"},
    {1050, "1k"},
    {1500, "1.5k"},
    {9999, "9.9k"},
    {999_999, "999.9k"},
    {1_000_000, "1kk"},
    {2_500_000, "2.5kk"},
    {1_234_567_890, "1.2kkk"},
    {-1500, "-1.5k"}
  ]

  test "damage_blocked matches Math.pow(d, 0.95) * 0.8, floored" do
    for {defense, expected} <- @damage_blocked,
        do: assert(Math.damage_blocked(defense) == expected)
  end

  test "base_xp_gained matches Math.pow(a, 1.5) * 0.8, floored" do
    for {attack, expected} <- @base_xp, do: assert(Math.base_xp_gained(attack) == expected)
  end

  test "base_adena_gained matches Math.pow(a, 2.65) * 0.05, floored" do
    for {attack, expected} <- @base_adena, do: assert(Math.base_adena_gained(attack) == expected)
  end

  test "xp_for_level matches Math.round(130L^2 + 130L)" do
    for {level, expected} <- @xp_for_level, do: assert(Math.xp_for_level(level) == expected)
  end

  test "js_round sends halves toward +infinity, unlike Elixir's round/1" do
    assert Math.js_round(0.5) == 1
    assert Math.js_round(1.5) == 2
    assert Math.js_round(2.5) == 3
    # round(-1.5) is -2 in Elixir but -1 in JavaScript.
    assert Math.js_round(-1.5) == -1
  end

  test "number/1 matches toLocaleString('en-US')" do
    for {n, expected} <- @numbers, do: assert(Format.number(n) == expected)
  end

  test "adena/1 matches formatAdena" do
    for {n, expected} <- @adenas, do: assert(Format.adena(n) == expected)
  end

  test "roll_chance short-circuits at both ends without drawing" do
    # Load-bearing for the draw order: an Elf's ambush risk is exactly 0 under the Newbie
    # Blessing, and must consume no randomness at all.
    MiniLineage.Game.Rng.put_source(fn -> raise "drew randomness when it should not have" end)

    refute Math.roll_chance(0)
    refute Math.roll_chance(-5)
    assert Math.roll_chance(100)
    assert Math.roll_chance(150)
  end
end
