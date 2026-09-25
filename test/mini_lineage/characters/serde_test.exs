defmodule MiniLineage.Characters.SerdeTest do
  @moduledoc """
  The boundary between a `%Player{}` and the JSON document in `characters.state`.

  Two things can go wrong here quietly. A field added to the struct and forgotten in `to_map/1`
  stops persisting, and nothing in the game would fail — the character simply loses it on the next
  load. And the document is untrusted input, so a hostile one must never be able to mint atoms.
  """
  use ExUnit.Case, async: true

  alias MiniLineage.Characters.Serde
  alias MiniLineage.Game.Player

  defp populated do
    %Player{
      name: "Hero",
      race_id: 2,
      health: 63,
      adena: 4_210,
      experience: 12_345,
      weapon_id: 3,
      armor_id: 4,
      dead: true,
      ambushed: true,
      coward: true,
      cheated: true,
      death_reason: "slain by a wandering Orc",
      total_battles: 41,
      total_ambushes: 7,
      consecutive_ambushes: 2,
      total_enemies_killed: 118,
      current_screen: "battle",
      effects: [
        %{
          id: "satisfied",
          type: :buff,
          group: "food",
          emoji: "🥓",
          label: "Satisfied",
          modifiers: [%{type: :max_health, value: 10}],
          expires_at: 1_700_000_090_000
        },
        %{
          id: "resting",
          type: :aura,
          group: nil,
          emoji: "💤",
          label: "Resting",
          modifiers: [],
          expires_at: nil
        }
      ],
      last_battle_narrative: %{
        narrative: %{
          crit_line: "A critical strike!",
          kill_line: "You cut them down.",
          deflection_line: "Your armor held.",
          outcome_line: "You walk away richer.",
          ambush_line: nil,
          fight_prompt: nil,
          next_move: "Search the hollow log"
        },
        outcome: %{
          enemies_killed: 4,
          hp_lost: 11,
          damage_blocked: 6,
          xp_gained: 92,
          adena_gained: 27,
          is_critical: true,
          is_level_up: false
        },
        ambushed: false,
        died: false,
        sound: "crit"
      }
    }
  end

  describe "the document covers the struct" do
    test "every field is written, and nothing that is not a field" do
      # Three deliberate exceptions, named so that a field forgotten by accident still fails here.
      # `version` describes the document rather than the character; `last_battle_narrative` is
      # transient, kept on the struct for the screen and stored in character_log instead; and
      # `pending_events` lives only until the process writes it, which is the same pass.
      struct_keys =
        %Player{}
        |> Map.from_struct()
        |> Map.keys()
        |> MapSet.new()
        |> MapSet.delete(:last_battle_narrative)
        |> MapSet.delete(:pending_events)

      written =
        %Player{}
        |> Serde.to_map()
        |> Map.keys()
        |> MapSet.new(&String.to_atom/1)
        |> MapSet.delete(:version)

      assert MapSet.difference(struct_keys, written) |> MapSet.to_list() == [],
             "a field is missing from Serde.to_map/1 and would stop persisting"

      assert MapSet.difference(written, struct_keys) |> MapSet.to_list() == []
    end

    test "the last battle is not in the document, because it is half its bytes" do
      # The fixture carries one; it belongs in character_log, and the round trip drops it.
      refute Map.has_key?(Serde.to_map(populated()), "last_battle_narrative")
      assert Serde.from_map(Serde.to_map(populated())).last_battle_narrative == nil
    end

    test "a fully populated character survives the round trip unchanged" do
      player = populated()

      assert player |> Serde.to_map() |> Serde.from_map() ==
               %{player | last_battle_narrative: nil}
    end

    test "and so does one that has done nothing at all" do
      assert %Player{} |> Serde.to_map() |> Serde.from_map() == %Player{}
    end

    test "the document is plain JSON — no atoms, no structs" do
      encoded = populated() |> Serde.to_map() |> Jason.encode!()

      assert encoded |> Jason.decode!() |> Serde.from_map() ==
               %{populated() | last_battle_narrative: nil}
    end
  end

  describe "the shape the document was written in" do
    test "is recorded, so a later reshape has something to branch on" do
      assert %Player{} |> Serde.to_map() |> Map.fetch!("version") == 1
    end

    test "and a document without one is refused, not assumed to be this shape" do
      # Nothing this build has ever written lacks the key, so a document that does is not a row
      # from an older build — it is a document the game did not write.
      unversioned = %Player{} |> Serde.to_map() |> Map.delete("version")

      assert_raise RuntimeError, ~r/carries no version/, fn -> Serde.from_map(unversioned) end
    end

    test "and one from a newer build is refused rather than quietly misread" do
      # A rolling deploy runs two versions at once. Reading a shape this build does not know would
      # otherwise default every unrecognised field and write the loss straight back.
      newer = %Player{name: "Hero"} |> Serde.to_map() |> Map.put("version", 99)

      assert_raise RuntimeError, ~r/version 99.*understands 1/, fn -> Serde.from_map(newer) end
    end
  end

  describe "an effect in the document" do
    # The catalog says what an effect is; the document only which one, and until when.
    test "is written as which one it is and until when, and nothing else" do
      [stored | _] = Serde.to_map(populated())["effects"]

      assert stored == %{"id" => "satisfied", "expires_at" => 1_700_000_090_000}
    end

    test "is read back from the catalog, whatever else a document claims about it" do
      loaded =
        Serde.from_map(%{
          "version" => 1,
          "effects" => [
            %{"id" => "satisfied", "expires_at" => 5, "label" => "Forged", "modifiers" => [%{}]}
          ]
        })

      assert [
               %{
                 id: "satisfied",
                 label: "Satisfied",
                 expires_at: 5,
                 modifiers: [%{type: :max_health}]
               }
             ] =
               loaded.effects
    end

    # An id the catalog no longer has, or never had, names nothing, so it is dropped rather than
    # guessed at, and no atom is minted from it.
    test "is dropped when the catalog does not know it" do
      hostile = "definitely_not_an_effect_#{System.unique_integer([:positive])}"

      loaded =
        Serde.from_map(%{"version" => 1, "effects" => [%{"id" => hostile}, %{"id" => "resting"}]})

      assert [%{id: "resting"}] = loaded.effects
      assert_raise ArgumentError, fn -> String.to_existing_atom(hostile) end
    end
  end

  describe "a hostile document" do
    test "missing fields fall back to a playable character rather than nil arithmetic" do
      loaded = Serde.from_map(%{"version" => 1})

      assert loaded.total_battles == 0
      assert loaded.total_ambushes == 0
      assert loaded.consecutive_ambushes == 0
      assert loaded.total_enemies_killed == 0
      assert loaded.effects == []
      assert loaded.dead == false
      assert loaded.last_battle_narrative == nil
    end

    test "a truthy-looking string is not a truthy flag" do
      loaded =
        Serde.from_map(%{"version" => 1, "dead" => "yes", "cheated" => 1, "coward" => "true"})

      refute loaded.dead
      refute loaded.cheated
      refute loaded.coward
    end
  end
end
