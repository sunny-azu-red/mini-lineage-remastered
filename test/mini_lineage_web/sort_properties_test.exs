defmodule MiniLineageWeb.SortPropertiesTest do
  @moduledoc """
  A table's sort for any rows and any clicks: the cycle a header walks, and the stability that
  keeps rows equal on a column from trading places on every live patch.
  """
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias MiniLineageWeb.Controls

  property "three clicks on one header walk it there, back, and off" do
    check all key <- member_of([:name, :level, :xp]),
              first <- member_of([:asc, :desc]),
              other <- member_of([nil, {:date, :asc}, {:date, :desc}]) do
      once = Controls.next_sort(other, key, first)
      twice = Controls.next_sort(once, key, first)

      assert once == {key, first}
      assert twice == {key, if(first == :asc, do: :desc, else: :asc)}
      assert Controls.next_sort(twice, key, first) == nil
    end
  end

  property "rows equal on the column keep the order they arrived in" do
    check all scores <- list_of(integer(1..4), max_length: 30),
              dir <- member_of([:asc, :desc]) do
      rows = Enum.with_index(scores, fn score, rank -> %{score: score, rank: rank} end)
      sorted = Controls.sort_rows(rows, {:score, dir}, &Map.fetch!(&1, &2))

      for {_score, tied} <- Enum.group_by(sorted, & &1.score) do
        assert Enum.map(tied, & &1.rank) == Enum.sort(Enum.map(tied, & &1.rank))
      end
    end
  end
end
