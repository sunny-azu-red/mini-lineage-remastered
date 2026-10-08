defmodule MiniLineage.Game.ClassTablesTest do
  use ExUnit.Case, async: true

  alias MiniLineage.Game.Classes

  # Every row of every class's `lvlUpgainData`, as the L2J datapack lists it.
  @fixture "test/fixtures/class_tables.json" |> File.read!() |> Jason.decode!()

  test "every class reproduces its datapack HP and MP table at every level" do
    for class <- Classes.all(), level <- 1..80 do
      row = @fixture[to_string(class.id)]

      assert_in_delta Classes.hp(class.id, level),
                      Enum.at(row["hp"], level - 1),
                      0.01,
                      "#{class.name} HP at #{level}"

      assert_in_delta Classes.mp(class.id, level),
                      Enum.at(row["mp"], level - 1),
                      0.01,
                      "#{class.name} MP at #{level}"
    end
  end

  test "the regen tables are the datapack's" do
    for level <- 1..80 do
      assert_in_delta Classes.hp_regen(level), Enum.at(@fixture["hp_regen"], level - 1), 1.0e-9
      assert_in_delta Classes.mp_regen(level), Enum.at(@fixture["mp_regen"], level - 1), 1.0e-9
    end
  end

  test "the class tree names each class by the datapack and the race it belongs to" do
    for class <- Classes.all() do
      assert class.name == @fixture[to_string(class.id)]["name"]
      assert Classes.root(class.id).race_id == class.race_id
      assert Classes.root(class.id).archetype == class.archetype
    end

    assert length(Classes.all()) == 53
    assert Classes.starting(0, :fighter).name == "Human Fighter"
    assert Classes.starting(3, :mystic).name == "Dark Mystic"
    assert Enum.map(Classes.children(44), & &1.name) == ["Orc Raider", "Monk"]
  end
end
