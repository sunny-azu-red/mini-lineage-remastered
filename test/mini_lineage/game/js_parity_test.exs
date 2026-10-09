defmodule MiniLineage.Game.JsParityTest do
  @moduledoc """
  Pins the arithmetic and formatting the port cannot verify by inspection: `Math.round`'s
  halves-toward-+infinity, and `toLocaleString('en-US')`,
  which Elixir has no ICU equivalent for. Every expectation below was produced by running the
  reference expressions in Node, not written by hand.
  """
  use ExUnit.Case, async: true

  alias MiniLineage.Game.{Format, Math}

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
    # Load-bearing for the draw order: a chance of exactly 0 or 100 consumes no randomness.
    MiniLineage.Game.Rng.put_source(fn -> raise "drew randomness when it should not have" end)

    refute Math.roll_chance(0)
    refute Math.roll_chance(-5)
    assert Math.roll_chance(100)
    assert Math.roll_chance(150)
  end
end
