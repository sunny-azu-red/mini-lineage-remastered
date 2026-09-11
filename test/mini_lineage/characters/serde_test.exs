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
      combat_until: 1_700_000_005_000,
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
      # Two deliberate exceptions, named so that a field forgotten by accident still fails here.
      # `version` describes the document rather than the character; `last_battle_narrative` is
      # transient, kept on the struct for the screen and stored in battle_log instead.
      struct_keys =
        %Player{}
        |> Map.from_struct()
        |> Map.keys()
        |> MapSet.new()
        |> MapSet.delete(:last_battle_narrative)

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
      # The fixture carries one; it belongs in battle_log, and the round trip drops it.
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

    test "a document written before versioning is the shape we have now" do
      # Every row already in the database predates this key, and none of them need converting.
      before_versioning = %Player{} |> Serde.to_map() |> Map.delete("version")

      assert Serde.from_map(before_versioning) == %Player{}
    end

    test "and one from a newer build is refused rather than quietly misread" do
      # A rolling deploy runs two versions at once. Reading a shape this build does not know would
      # otherwise default every unrecognised field and write the loss straight back.
      newer = %Player{name: "Hero"} |> Serde.to_map() |> Map.put("version", 99)

      assert_raise RuntimeError, ~r/version 99.*understands 1/, fn -> Serde.from_map(newer) end
    end
  end

  describe "a hostile document" do
    test "cannot mint an atom through an effect's type" do
      hostile = "definitely_not_an_effect_type_#{System.unique_integer([:positive])}"

      loaded =
        Serde.from_map(%{
          "effects" => [
            %{
              "id" => "x",
              "type" => hostile,
              "modifiers" => []
            }
          ]
        })

      assert [%{type: :buff}] = loaded.effects
      # Names the exact string rather than watching a global counter, which any concurrent atom
      # creation would move.
      assert_raise ArgumentError, fn -> String.to_existing_atom(hostile) end
    end

    test "cannot mint an atom through a modifier's type, and the modifier is dropped" do
      hostile = "not_a_stat_#{System.unique_integer([:positive])}"

      loaded =
        Serde.from_map(%{
          "effects" => [
            %{
              "id" => "x",
              "type" => "buff",
              "modifiers" => [
                %{"type" => hostile, "value" => 999},
                %{"type" => "attack", "value" => 3}
              ]
            }
          ]
        })

      assert [%{modifiers: [%{type: :attack, value: 3}]}] = loaded.effects
      assert_raise ArgumentError, fn -> String.to_existing_atom(hostile) end
    end

    test "a malformed modifier is dropped rather than crashing the load" do
      loaded =
        Serde.from_map(%{
          "effects" => [%{"id" => "x", "type" => "buff", "modifiers" => ["nonsense", %{}, nil]}]
        })

      assert [%{modifiers: []}] = loaded.effects
    end

    test "missing fields fall back to a playable character rather than nil arithmetic" do
      loaded = Serde.from_map(%{})

      assert loaded.total_battles == 0
      assert loaded.total_ambushes == 0
      assert loaded.consecutive_ambushes == 0
      assert loaded.total_enemies_killed == 0
      assert loaded.effects == []
      assert loaded.dead == false
      assert loaded.last_battle_narrative == nil
    end

    test "a truthy-looking string is not a truthy flag" do
      loaded = Serde.from_map(%{"dead" => "yes", "cheated" => 1, "coward" => "true"})

      refute loaded.dead
      refute loaded.cheated
      refute loaded.coward
    end
  end
end
