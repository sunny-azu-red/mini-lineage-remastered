defmodule MiniLineage.Game.SkillsTest do
  @moduledoc """
  Rules §19 past the fight: an aura outlasting it as an icon that changes the stat it names, Relax on
  the tick of rest, what is stored, and the warning a weapon none of the skills can use brings.
  """
  use ExUnit.Case, async: true

  alias MiniLineage.Characters.Serde
  alias MiniLineage.Game.{Actions, Clock, Constants, Math, Player, Rng}

  @noon ~U[2026-07-01 12:00:00Z]

  setup do
    Clock.put_now(@noon)
    :ok
  end

  defp character(race_id, path, level, skills) do
    {player, _} = Player.initialize(%Player{}, Constants.race(race_id), path, "Adept")
    player = %{player | experience: Math.xp_for_level(level)}
    Player.restore_fully(%{player | skills: Map.merge(player.skills, skills)})
  end

  defp aura?(player, id), do: Enum.any?(Player.auras(player), &(&1.id == id))

  test "an aura raised outlasts the fight as an icon, changes its stat, and fades in 20 minutes" do
    elf = character(2, :fighter, 5, %{"Defense Aura" => 1})
    raised = Player.put_buffs(elf, ["Defense Aura"])

    assert aura?(raised, "defense_aura")
    assert_in_delta Player.stats(raised).p_def, Player.stats(elf).p_def * 1.08, 1.0e-9

    Clock.put_now(DateTime.add(@noon, 20 * 60 + 1))
    refute aura?(raised, "defense_aura")
    assert {%{buffs: buffs}, true} = Player.regenerate(raised)
    assert buffs == %{}
  end

  test "a hunt keeps the auras it raised" do
    Rng.put_source(fn -> 0.0 end)
    elf = character(2, :fighter, 5, %{"Defense Aura" => 1})
    {hunted, {:ok, _}} = Actions.hunt(elf)

    assert Player.buffs_up(hunted) == ["Defense Aura"]
  end

  test "Relax mends 5 HP more a tick for 3 MP, while HP is short and the MP lasts" do
    plain = character(1, :fighter, 5, %{})
    plain = %{plain | health: div(plain.health, 2)}
    relaxed = %{plain | skills: Map.put(plain.skills, "Relax", 1)}

    assert aura?(relaxed, "relax")
    {rested, true} = Player.regenerate(plain)
    {relaxed_rest, true} = Player.regenerate(relaxed)

    assert relaxed_rest.health == rested.health + 5
    assert relaxed_rest.mp == rested.mp - 3

    refute aura?(%{relaxed | mp: 2}, "relax")
    refute aura?(%{relaxed | health: Player.stats(relaxed).max_hp}, "relax")
  end

  test "auras are stored to the millisecond they fade, and only auras the rules know" do
    elf = Player.put_buffs(character(2, :fighter, 5, %{"Defense Aura" => 1}), ["Defense Aura"])
    stored = elf |> Serde.to_map() |> Jason.encode!() |> Jason.decode!()

    assert Serde.from_map(stored).buffs == elf.buffs

    forged = put_in(stored["buffs"], %{"Heal" => 1, "Haste" => 1, "Defense Aura" => "soon"})
    assert Serde.from_map(forged).buffs == %{}
  end

  test "a weapon none of the character's weapon skills can use is put on with a warning" do
    human = character(0, :fighter, 5, %{"Mortal Blow" => 1})
    gloves = %{id: "g", name: "Training Gloves", equipped: false}
    dagger = %{id: "d", name: "Dagger", equipped: false}
    human = %{human | items: human.items ++ [gloves, dagger]}

    {_, {:ok, warned}} = Actions.equip(human, "g")
    assert warned.type == :danger
    assert warned.text =~ "none of your Mortal Blow or Power Strike"

    assert {_, {:ok, %{type: :info}}} = Actions.equip(human, "d")
  end
end
