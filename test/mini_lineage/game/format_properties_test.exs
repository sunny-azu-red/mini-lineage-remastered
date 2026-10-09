defmodule MiniLineage.Game.FormatPropertiesTest do
  @moduledoc """
  What the formatters promise for every input, not only the rows in their fixtures. The fixtures
  stay the contract with the JavaScript twins; a counterexample found here becomes a row there.
  """
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias MiniLineage.Game.{Format, Math, Rules}

  describe "the short form" do
    property "drops everything past the tenth, as integer arithmetic would" do
      check all value <- big(), max_runs: 500 do
        assert Format.short(value) == truncated(value)
      end
    end
  end

  describe "levels" do
    property "a level's own threshold is that level, up to the last one" do
      check all level <- integer(1..Rules.max_level()) do
        assert Math.level_for_xp(Math.xp_for_level(level)) == level
      end
    end

    property "experience never takes a level away" do
      check all xp <- non_negative_integer(), more <- non_negative_integer() do
        assert Math.level_for_xp(xp + more) >= Math.level_for_xp(xp)
      end
    end
  end

  # Weighted across every unit, since a uniform draw over the whole range is almost always "kkk".
  defp big do
    gen all magnitude <-
              one_of([
                integer(0..999),
                integer(1_000..999_999),
                integer(1_000_000..999_999_999),
                integer(1_000_000_000..1_000_000_000_000)
              ]),
            sign <- member_of([1, -1]) do
      sign * magnitude
    end
  end

  defp truncated(value) when abs(value) <= 999, do: Integer.to_string(value)

  defp truncated(value) do
    {unit, suffix} =
      Enum.find(
        [{1_000_000_000, "kkk"}, {1_000_000, "kk"}, {1_000, "k"}],
        &(abs(value) >= elem(&1, 0))
      )

    tenths = div(abs(value), div(unit, 10))
    sign = if value < 0, do: "-", else: ""

    digits =
      if rem(tenths, 10) == 0,
        do: "#{div(tenths, 10)}",
        else: "#{div(tenths, 10)}.#{rem(tenths, 10)}"

    sign <> digits <> suffix
  end
end
