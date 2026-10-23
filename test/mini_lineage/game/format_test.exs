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

  test "an amount of Adena is the coin, the figure and the word, in gold" do
    assert Format.adena(12_500) == ~s(<span class="adena">🪙 12,500 Adena</span>)
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

  describe "the percentages the JavaScript must agree on" do
    test "are written the same way here" do
      %{"cases" => cases} =
        "test/fixtures/percent_format.json" |> File.read!() |> Jason.decode!()

      for [value, expected] <- cases do
        assert Format.percent(value) == expected, "#{value} formatted as #{Format.percent(value)}"
      end
    end
  end

  describe "the tenths the JavaScript must agree on" do
    test "are written the same way here" do
      %{"cases" => cases} = "test/fixtures/tenths_format.json" |> File.read!() |> Jason.decode!()

      for [value, expected] <- cases do
        assert Format.tenths(value) == expected, "#{value} formatted as #{Format.tenths(value)}"
      end
    end
  end

  describe "the countdowns the JavaScript must agree on" do
    test "are written the same way here" do
      %{"badge" => badge, "spoken" => spoken} =
        "test/fixtures/effect_timer.json" |> File.read!() |> Jason.decode!()

      for [ms, expected] <- badge, do: assert(Format.countdown(ms) == expected, "#{ms}")
      for [ms, expected] <- spoken, do: assert(Format.remaining(ms) == expected, "#{ms}")
    end
  end

  describe "the stamps the JavaScript must agree on" do
    test "age the same way here" do
      %{"cap_ms" => cap, "cases" => cases} =
        "test/fixtures/stamp_format.json" |> File.read!() |> Jason.decode!()

      for [age, form, date, expected] <- cases do
        assert Format.stamp(age, cap, String.to_existing_atom(form), date) == expected,
               "#{age} #{form}"
      end
    end

    test "and turn into a day the server writes, the year only when it is not this one" do
      now = ~U[2026-10-24 12:00:00Z]

      assert Format.date(~U[2026-10-17 15:10:00Z], now, :short) == "17 Oct"
      assert Format.date(~U[2026-10-17 15:10:00Z], now, :long) == "17 October"
      assert Format.date(~U[2025-12-31 23:00:00Z], now, :short) == "31 Dec 2025"
    end

    test "with the whole instant in the tooltip, on a twelve-hour clock in a zone it names" do
      local = &DateTime.shift_zone!(&1, "Europe/Bucharest")

      assert Format.instant(local.(~U[2026-10-17 12:10:00Z])) == "17 Oct 2026, 3:10 pm EEST"
      assert Format.instant(local.(~U[2026-01-04 22:05:00Z])) == "5 Jan 2026, 12:05 am EET"
    end
  end

  describe "slugify" do
    test "makes a race label safe for an id" do
      assert Format.slugify("Dark Elf") == "dark-elf"
      assert Format.slugify("Orc") == "orc"
    end
  end
end
