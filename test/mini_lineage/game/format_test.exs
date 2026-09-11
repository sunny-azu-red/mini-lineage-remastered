defmodule MiniLineage.Game.FormatTest do
  @moduledoc """
  The numbers as a player reads them.

  Adena is shortened once it passes a thousand, and the boundaries are where a formatter goes
  wrong: 999 and 1,000 sit either side of one, and a value that lands exactly on a unit must not
  read as "1.0k". The client animates the same figure with its own copy of this in hooks.js, but
  every count ends on the server's text, so only this side is ever read.
  """
  use ExUnit.Case, async: true

  alias MiniLineage.Game.Format

  describe "adena" do
    test "is written out in full while it still fits" do
      assert Format.adena(0) == "0"
      assert Format.adena(7) == "7"
      assert Format.adena(999) == "999"
    end

    test "and shortens by a thousand past that, at the exact boundary" do
      assert Format.adena(1_000) == "1k"
      assert Format.adena(1_500) == "1.5k"
      assert Format.adena(999_999) == "999.9k"
    end

    test "by a million, then by a billion" do
      assert Format.adena(1_000_000) == "1kk"
      assert Format.adena(2_800_000) == "2.8kk"
      assert Format.adena(1_000_000_000) == "1kkk"
      assert Format.adena(250_000_000_000) == "250kkk"
    end

    test "drops a trailing .0 rather than showing it" do
      for value <- [1_000, 10_000, 1_000_000, 1_000_000_000],
          do: refute(String.contains?(Format.adena(value), ".0"), Format.adena(value))
    end

    test "rounds down, never up, so a purse never reads richer than it is" do
      assert Format.adena(1_999) == "1.9k"
      assert Format.adena(1_099) == "1k"
    end

    test "and carries a debt's sign" do
      assert Format.adena(-50) == "-50"
      assert Format.adena(-1_500) == "-1.5k"
    end
  end

  describe "the values the JavaScript must agree on" do
    test "are formatted the same way here" do
      # The count-up animation formats its own intermediate frames, so hooks.js carries a second
      # implementation of this — it cannot be removed without the number jumping format mid-count.
      # Both sides read this file, so a divergence fails a test instead of wobbling on screen.
      %{"cases" => cases} =
        "test/fixtures/adena_format.json" |> File.read!() |> Jason.decode!()

      for [value, expected] <- cases do
        assert Format.adena(value) == expected, "#{value} formatted as #{Format.adena(value)}"
      end
    end
  end

  describe "pluralize" do
    test "writes a single thing as prose rather than as a figure" do
      # "a battle" reads where "1 battle" counts, and these strings sit inside sentences.
      assert Format.pluralize("battle", "battles", 1) == "a battle"
      assert Format.pluralize("ambush", "ambushes", 1) == "an ambush"
      assert Format.pluralize("battle", "battles", 2) == "2 battles"
      assert Format.pluralize("battle", "battles", 0) == "0 battles"
    end

    test "and puts the emoji with the noun, not with the count" do
      assert Format.pluralize("Orc", "Orcs", 1, "🧟") == "an 🧟 Orc"
      assert Format.pluralize("Orc", "Orcs", 3, "🧟") == "3 🧟 Orcs"
    end

    test "and groups the digits of a large count" do
      assert Format.pluralize("battle", "battles", 4200) =~ "4,200"
    end
  end

  describe "slugify" do
    test "makes a race label safe for the board's own URL" do
      assert Format.slugify("Dark Elf") == "dark-elf"
      assert Format.slugify("Orc") == "orc"
    end
  end
end
