defmodule MiniLineage.Characters.SerdeTest do
  @moduledoc """
  The boundary between a `%Player{}` and the JSON document in `characters.state`. A field
  forgotten in `to_map/1` silently stops persisting, and the document is untrusted input, so a
  hostile one must never be able to mint atoms.
  """
  use ExUnit.Case, async: true

  alias MiniLineage.Characters.Serde
  alias MiniLineage.Game.{Narratives, Player}

  defp populated do
    %Player{
      name: "Hero",
      race_id: 2,
      path: :mystic,
      health: 63,
      mp: 41,
      adena: 4_210,
      experience: 12_345,
      sp: 321,
      location: "gludio"
    }
  end

  describe "the document covers the struct" do
    test "every field is written, and nothing that is not a field" do
      # The inventory and the fights are their own tables (rules §23 and §20), so the document
      # leaves them out.
      struct_keys =
        %Player{}
        |> Map.from_struct()
        |> Map.keys()
        |> MapSet.new()
        |> MapSet.difference(MapSet.new([:items, :encounter]))

      written =
        %Player{}
        |> Serde.to_map()
        |> Map.keys()
        |> MapSet.new(&String.to_atom/1)
        |> MapSet.delete(:version)

      assert written == struct_keys
    end

    test "a fully populated character survives the round trip, through JSON, unchanged" do
      fallen = %{
        populated()
        | dead: true,
          killer: "Elder Keltir",
          fell_at: "obelisk-of-victory",
          died_at: 1_792_854_600_000,
          death_line: hd(Narratives.death())
      }

      for player <- [populated(), %{populated() | path: :fighter}, fallen, %Player{}] do
        assert player |> Serde.to_map() |> Jason.encode!() |> Jason.decode!() |> Serde.from_map() ==
                 player
      end
    end
  end

  describe "the shape the document was written in" do
    test "is recorded, so a later reshape has something to branch on" do
      assert %Player{} |> Serde.to_map() |> Map.fetch!("version") == 3
    end

    test "and a document without one is refused, not assumed to be this shape" do
      unversioned = %Player{} |> Serde.to_map() |> Map.delete("version")

      assert_raise RuntimeError, ~r/carries no version/, fn -> Serde.from_map(unversioned) end
    end

    test "and one from a newer build is refused rather than quietly misread" do
      newer = %Player{name: "Hero"} |> Serde.to_map() |> Map.put("version", 99)

      assert_raise RuntimeError, ~r/version 99.*understands 3/, fn -> Serde.from_map(newer) end
    end

    test "a version 2 document's merged skills come back a line lower, the rest as they were" do
      skills = %{"Heal" => 2, "Ice Bolt" => 1, "Vampiric Touch" => 2, "Wind Strike" => 2}
      v2 = %{populated() | skills: skills} |> Serde.to_map() |> Map.put("version", 2)

      assert Serde.from_map(v2).skills ==
               %{"Heal" => 1, "Ice Bolt" => 1, "Vampiric Touch" => 1, "Wind Strike" => 2}

      v3 = %{populated() | skills: skills} |> Serde.to_map()
      assert Serde.from_map(v3).skills == skills |> Map.put("Vampiric Touch", 1)
    end
  end

  describe "where the character stands" do
    test "a version 1 document, from before anyone could leave, is in its race's village" do
      v1 = populated() |> Serde.to_map() |> Map.put("version", 1) |> Map.delete("location")

      assert Serde.from_map(v1).location == "elven-village"
    end

    test "and a town this build does not have, or cannot be stood in, puts it back there too" do
      for slug <- ["atlantis", "giran", 7] do
        doc = populated() |> Serde.to_map() |> Map.put("location", slug)
        assert Serde.from_map(doc).location == "elven-village", inspect(slug)
      end
    end

    test "and a town since renamed keeps whoever stands in it" do
      doc = populated() |> Serde.to_map() |> Map.put("location", "dark-elven-village")
      assert Serde.from_map(doc).location == "dark-elf-village"
    end

    test "while a visitor stands nowhere" do
      assert %Player{} |> Serde.to_map() |> Serde.from_map() |> Map.fetch!(:location) == nil
    end
  end

  test "a run from before the first hunt has earned no SP, and is alive" do
    doc = populated() |> Serde.to_map() |> Map.drop(["sp", "dead", "killer"])
    assert %Player{sp: 0, dead: false, killer: nil} = Serde.from_map(doc)
  end

  test "a fallen run keeps only a ground and a death line the game still has, the line being drawn raw" do
    doc =
      populated()
      |> Serde.to_map()
      |> Map.merge(%{"fell_at" => "nowhere", "death_line" => "<script>alert(1)</script>"})

    assert %Player{fell_at: nil, death_line: nil} = Serde.from_map(doc)
  end

  test "a skill stored past the levels the trainer now teaches is read at its last" do
    doc = populated() |> Serde.to_map() |> Map.put("skills", %{"Wind Strike" => 5})
    assert Serde.from_map(doc).skills == %{"Wind Strike" => 3}
  end

  test "a path that is not Fighter or Mystic is read as none, and mints no atom" do
    hostile = "archmage_#{System.unique_integer([:positive])}"

    assert Serde.from_map(%{"version" => 1, "path" => hostile}).path == nil
    assert_raise ArgumentError, fn -> String.to_existing_atom(hostile) end
  end
end
