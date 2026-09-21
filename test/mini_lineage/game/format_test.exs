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
    test "adena is formatted the same way here" do
      # The count-up animation formats its own intermediate frames, so hooks.js carries a second
      # implementation of this — it cannot be removed without the number jumping format mid-count.
      # Both sides read this file, so a divergence fails a test instead of wobbling on screen.
      %{"cases" => cases} =
        "test/fixtures/adena_format.json" |> File.read!() |> Jason.decode!()

      for [value, expected] <- cases do
        assert Format.adena(value) == expected, "#{value} formatted as #{Format.adena(value)}"
      end
    end

    test "and so is a countdown" do
      # The server renders the first frame and `timerLabel` in hooks.js repaints it every second,
      # so a divergence shows as the number changing shape the instant the hook takes over.
      %{"cases" => cases} =
        "test/fixtures/effect_timer.json" |> File.read!() |> Jason.decode!()

      for [ms, expected] <- cases do
        assert Format.countdown(ms) == expected, "#{ms}ms labelled #{Format.countdown(ms)}"
      end
    end

    test "and so is the same time said in a sentence" do
      # The badge has a few pixels and says "1m"; a paragraph has room to say "1m 30s". Twinned
      # with `remainingLabel` in hooks.js off the same table, for the same reason.
      %{"spoken" => cases} =
        "test/fixtures/effect_timer.json" |> File.read!() |> Jason.decode!()

      for [ms, expected] <- cases do
        assert Format.remaining(ms) == expected, "#{ms}ms spoken as #{Format.remaining(ms)}"
      end
    end
  end

  describe "a modifier" do
    # Every one of these is read as a change to a stat, so the sign is half the meaning: "-4% Ambush
    # Risk" is a blessing and "+4%" is a curse, and without the mark neither says which.
    test "carries its own sign, so a gift and a cost cannot be confused" do
      assert Format.modifier(20) == "+20"
      assert Format.modifier(-4) == "-4"
      assert Format.modifier(0) == "0"
    end

    test "unless it multiplies, where a sign would be nonsense" do
      assert Format.modifier(4, true) == "4"
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
