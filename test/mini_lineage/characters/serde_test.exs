defmodule MiniLineage.Characters.SerdeTest do
  @moduledoc """
  The boundary between a `%Player{}` and the JSON document in `characters.state`. A field
  forgotten in `to_map/1` silently stops persisting, and the document is untrusted input, so a
  hostile one must never be able to mint atoms.
  """
  use ExUnit.Case, async: true

  alias MiniLineage.Characters.Serde
  alias MiniLineage.Game.Player

  defp populated do
    %Player{
      name: "Hero",
      race_id: 2,
      path: :mystic,
      health: 63,
      mp: 41,
      adena: 4_210,
      experience: 12_345
    }
  end

  describe "the document covers the struct" do
    test "every field is written, and nothing that is not a field" do
      struct_keys = %Player{} |> Map.from_struct() |> Map.keys() |> MapSet.new()

      written =
        %Player{}
        |> Serde.to_map()
        |> Map.keys()
        |> MapSet.new(&String.to_atom/1)
        |> MapSet.delete(:version)

      assert written == struct_keys
    end

    test "a fully populated character survives the round trip, through JSON, unchanged" do
      for player <- [populated(), %{populated() | path: :fighter}, %Player{}] do
        assert player |> Serde.to_map() |> Jason.encode!() |> Jason.decode!() |> Serde.from_map() ==
                 player
      end
    end
  end

  describe "the shape the document was written in" do
    test "is recorded, so a later reshape has something to branch on" do
      assert %Player{} |> Serde.to_map() |> Map.fetch!("version") == 1
    end

    test "and a document without one is refused, not assumed to be this shape" do
      unversioned = %Player{} |> Serde.to_map() |> Map.delete("version")

      assert_raise RuntimeError, ~r/carries no version/, fn -> Serde.from_map(unversioned) end
    end

    test "and one from a newer build is refused rather than quietly misread" do
      newer = %Player{name: "Hero"} |> Serde.to_map() |> Map.put("version", 99)

      assert_raise RuntimeError, ~r/version 99.*understands 1/, fn -> Serde.from_map(newer) end
    end
  end

  test "a path that is not Fighter or Mystic is read as none, and mints no atom" do
    hostile = "archmage_#{System.unique_integer([:positive])}"

    assert Serde.from_map(%{"version" => 1, "path" => hostile}).path == nil
    assert_raise ArgumentError, fn -> String.to_existing_atom(hostile) end
  end
end
