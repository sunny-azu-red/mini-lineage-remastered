defmodule MiniLineage.Game.FormatTest do
  @moduledoc """
  The numbers as a player reads them.

  A big figure (a purse, a level's EXP) is shortened past a thousand, and the boundaries are where a formatter goes wrong: 999
  and 1,000 sit either side of one, and a value landing exactly on a unit must not read "1.0k".
  """
  use ExUnit.Case, async: true

  alias MiniLineage.Game.Format

  describe "the short form" do
    test "is written out in full while it still fits" do
      assert Format.short(0) == "0"
      assert Format.short(7) == "7"
      assert Format.short(999) == "999"
    end

    test "and shortens by a thousand past that, at the exact boundary" do
      assert Format.short(1_000) == "1k"
      assert Format.short(1_500) == "1.5k"
      assert Format.short(999_999) == "999.9k"
    end

    test "by a million, then by a billion" do
      assert Format.short(1_000_000) == "1kk"
      assert Format.short(2_800_000) == "2.8kk"
      assert Format.short(1_000_000_000) == "1kkk"
      assert Format.short(250_000_000_000) == "250kkk"
    end

    test "drops a trailing .0 rather than showing it" do
      for value <- [1_000, 10_000, 1_000_000, 1_000_000_000],
          do: refute(String.contains?(Format.short(value), ".0"), Format.short(value))
    end

    test "rounds down, never up, so a purse never reads richer than it is" do
      assert Format.short(1_999) == "1.9k"
      assert Format.short(1_099) == "1k"
    end

    test "and carries a debt's sign" do
      assert Format.short(-50) == "-50"
      assert Format.short(-1_500) == "-1.5k"
    end
  end

  describe "the values the JavaScript must agree on" do
    test "is shortened the same way here" do
      # hooks/animated-values.js formats the count-up's own frames with a twin of this. Both read
      # this table, so a divergence fails a test instead of wobbling on screen.
      %{"cases" => cases} =
        "test/fixtures/short_format.json" |> File.read!() |> Jason.decode!()

      for [value, expected] <- cases do
        assert Format.short(value) == expected, "#{value} formatted as #{Format.short(value)}"
      end
    end
  end

  describe "slugify" do
    test "makes a race label safe for an id" do
      assert Format.slugify("Dark Elf") == "dark-elf"
      assert Format.slugify("Orc") == "orc"
    end
  end
end
