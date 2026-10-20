defmodule MiniLineageWeb.KeptTest do
  @moduledoc """
  The kept cookie, read as the reader-typed input it is: what the game can draw comes through, and
  anything else is dropped rather than raised.
  """
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias MiniLineageWeb.Kept

  @nothing %{folds: %{}, sorts: %{}, sound: true}

  test "reads every kind the game draws" do
    raw =
      URI.encode_query(%{
        "panel:orders" => "0",
        "panel:inventory" => "1",
        "table:items" => "name:desc",
        "sound:effects" => "0"
      })

    assert Kept.read(raw) == %{
             folds: %{"orders" => false, "inventory" => true},
             sorts: %{"items" => {"name", :desc}},
             sound: false
           }
  end

  test "no cookie, an empty one or a broken one keeps nothing" do
    for raw <- [nil, "", "panel%3Aorders=%zz", "%", 42], do: assert(Kept.read(raw) == @nothing)
  end

  test "drops a kind, a panel id or a value nothing draws" do
    raw = "colour%3Agold=1&panel%3AOrders=0&panel%3Aorders=maybe&panel%3A=0&sound%3Aeffects=1"

    assert Kept.read(raw) == @nothing
  end

  test "drops a sort for a table that does not remember, or on a key it lacks" do
    raw = "table%3Alessons=sp%3Adesc&table%3Aitems=price%3Aasc&table%3Aitems2=name%3Aasc"

    assert Kept.read(raw).sorts == %{}
  end

  test "keeps no more folds than any page could have" do
    raw = Enum.map_join(1..100, "&", &"panel%3Ap#{&1}=0")

    assert map_size(Kept.read(raw).folds) == 32
  end

  test "a fold the browser reports is kept only for an id a panel could have, and only so many" do
    assert Kept.fold(%{}, "orders", false) == %{"orders" => false}
    assert Kept.fold(%{}, "<script>", false) == %{}
    assert Kept.fold(%{}, 7, false) == %{}

    full = Map.new(1..32, &{"p#{&1}", true})
    assert Kept.fold(full, "orders", false) == full
    assert Kept.fold(full, "p1", false)["p1"] == false
  end

  property "any value reads without raising, into folds and sorts the game can draw" do
    check all raw <- one_of([string(:printable), string(:ascii)]), max_runs: 300 do
      %{folds: folds, sorts: sorts, sound: sound} = Kept.read(raw)

      assert is_boolean(sound)

      assert Enum.all?(folds, fn {id, open} ->
               id =~ ~r/\A[a-z][a-z0-9-]*\z/ and is_boolean(open)
             end)

      assert Map.keys(sorts) -- ["items"] == []
    end
  end
end
