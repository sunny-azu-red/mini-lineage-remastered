defmodule MiniLineage.Game.SkillsTest do
  @moduledoc """
  Rules §19 past the fight: an aura outlasting it as an icon that changes the stat it names, Relax on
  the tick of rest, a mastery adding to its stat, what is stored, and the warning a weapon none of
  the skills can use brings.
  """
  use ExUnit.Case, async: true

  alias MiniLineage.Characters.Serde
  alias MiniLineage.Game.{Actions, Clock, Constants, Hunt, Math, Player, Rng, Rules}

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

  test "an aura raised outlasts the fight as an icon, changes its stat, and fades in 2 minutes" do
    elf = character(2, :fighter, 5, %{"Defense Aura" => 1})
    raised = Player.put_buffs(elf, ["Defense Aura"])

    assert aura?(raised, "defense_aura")
    assert_in_delta Player.stats(raised).p_def, Player.stats(elf).p_def * 1.08, 1.0e-9

    Clock.put_now(DateTime.add(@noon, 2 * 60 - 1))
    assert aura?(raised, "defense_aura")

    Clock.put_now(DateTime.add(@noon, 2 * 60 + 1))
    refute aura?(raised, "defense_aura")
    assert {%{buffs: buffs}, true} = Player.regenerate(raised)
    assert buffs == %{}
  end

  test "a Mystic casts Shield, or the Orc's Soul Shield, on itself, as a P.Def aura of its own" do
    for {race_id, skill, id} <- [{3, "Shield", "shield"}, {1, "Soul Shield", "soul_shield"}] do
      mystic = character(race_id, :mystic, 7, %{skill => 1})
      raised = Player.put_buffs(mystic, [skill])

      assert aura?(raised, id)
      assert_in_delta Player.stats(raised).p_def, Player.stats(mystic).p_def * 1.08, 1.0e-9
    end
  end

  test "a hunt keeps the auras it raised" do
    Rng.put_source(fn -> 0.0 end)
    elf = character(2, :fighter, 5, %{"Defense Aura" => 1})
    {hunted, {:ok, _}} = Actions.hunt(elf)

    assert Player.buffs_up(hunted) == ["Defense Aura"]
  end

  test "a skill its orders leave unused is never used in a hunt, until it is ordered used again" do
    Rng.put_source(fn -> 0.0 end)
    elf = character(2, :fighter, 5, %{"Defense Aura" => 1})
    {idle, {:ok, _}} = Actions.use_skill(elf, "Defense Aura", false)
    {hunted, {:ok, _}} = Actions.hunt(idle)
    assert Player.buffs_up(hunted) == []

    {again, {:ok, _}} = Actions.use_skill(idle, "Defense Aura", true)
    assert again.unused == []
    {hunted, {:ok, _}} = Actions.hunt(again)
    assert Player.buffs_up(hunted) == ["Defense Aura"]
  end

  test "any skill it knows but a mastery may be left unused, and the order is kept" do
    orc = character(1, :mystic, 7, %{"Soul Cry" => 1, "Life Drain" => 1})
    {orc, {:ok, _}} = Actions.use_skill(orc, "Soul Cry", false)
    {orc, {:ok, _}} = Actions.use_skill(orc, "Life Drain", false)
    assert orc.unused == ["Life Drain", "Soul Cry"]
    assert Enum.map(Player.fighting_skills(orc), & &1.name) == ["Chill Flame"]

    healer = character(2, :mystic, 1, %{"Self Heal" => 1, "Robe Mastery" => 1})
    resting = character(1, :fighter, 5, %{"Relax" => 1})
    assert {_, {:ok, nil}} = Actions.use_skill(healer, "Self Heal", false)
    assert {_, {:ok, nil}} = Actions.use_skill(resting, "Relax", false)
    assert {_, {:error, :no_switch, _}} = Actions.use_skill(healer, "Robe Mastery", false)
    assert {_, {:error, :no_switch, _}} = Actions.use_skill(orc, "Wind Strike", false)

    stored = orc |> Serde.to_map() |> JSON.encode!() |> JSON.decode!()
    assert Serde.from_map(stored).unused == ["Life Drain", "Soul Cry"]
    assert Serde.from_map(Map.put(stored, "unused", ["Nonsense", 3])).unused == []
    assert Serde.from_map(Map.delete(stored, "unused")).unused == []
  end

  test "a heal left unused mends nothing before the pull, and its shares wait until it is used" do
    healer = character(2, :mystic, 1, %{"Self Heal" => 1})
    hurt = %{healer | health: 1}
    {unused, {:ok, nil}} = Actions.use_skill(hurt, "Self Heal", false)

    refute Player.heals_in_use?(unused)
    assert {_, {:error, :heal_unused, _}} = Actions.heal_at(unused, :pull, 30)

    foe = Hunt.foe(Rules.monster("Young Keltir"))
    stats = Player.stats(unused)
    pulled = Hunt.fight(stats, unused, Player.fighting_skills(unused), foe)
    assert {[], 1} = pulled.before
    assert {[_ | _], _} = Hunt.fight(stats, hurt, Player.fighting_skills(hurt), foe).before

    {used, {:ok, nil}} = Actions.use_skill(unused, "Self Heal", true)
    assert {_, {:ok, nil}} = Actions.heal_at(used, :pull, 30)
  end

  test "Relax left unused neither mends on the tick of rest nor spends its MP" do
    orc = %{character(1, :fighter, 5, %{"Relax" => 1}) | health: 1}
    assert aura?(orc, "relax")

    {unused, {:ok, nil}} = Actions.use_skill(orc, "Relax", false)
    refute aura?(unused, "relax")
    {rested, _} = Player.regenerate(unused)
    {relaxed, _} = Player.regenerate(orc)
    assert rested.mp > relaxed.mp
  end

  test "a reset puts every order back to the ones a new character starts with" do
    healer = character(2, :mystic, 1, %{"Self Heal" => 1, "Wind Strike" => 1})
    assert Player.default_orders?(healer)

    {healer, {:ok, _}} = Actions.potion_at(healer, 0)
    {healer, {:ok, _}} = Actions.heal_at(healer, :pull, 30)
    {healer, {:ok, _}} = Actions.heal_at(healer, :fight, 50)
    {healer, {:ok, _}} = Actions.use_skill(healer, "Wind Strike", false)
    refute Player.default_orders?(healer)

    {reset, {:ok, _}} = Actions.reset_orders(healer)
    assert %{potion_at: 50, heal_pull_at: 70, heal_fight_at: 0, unused: []} = reset
    assert Player.default_orders?(reset)
    assert reset.skills == healer.skills
    assert {_, {:error, :invalid, _}} = Actions.reset_orders(%Player{})
  end

  test "a mastery is never cast and never an order, only what it adds" do
    fighter = character(0, :fighter, 15, %{"Armor Mastery" => 3})
    refute "Armor Mastery" in Enum.map(Player.fighting_skills(fighter), & &1.name)
    refute "Armor Mastery" in Player.switchable(fighter)
    assert {_, {:error, :no_switch, _}} = Actions.use_skill(fighter, "Armor Mastery", false)
  end

  test "Armor Mastery's P.Def holds in anything, its Evasion only in light armour" do
    fighter = character(0, :fighter, 15, %{})
    master = %{fighter | skills: Map.put(fighter.skills, "Armor Mastery", 3)}
    shirtless = fn p -> %{p | items: Enum.reject(p.items, &(&1.name == "Squire's Shirt"))} end

    assert_in_delta Player.stats(master).p_def - Player.stats(fighter).p_def, 14, 1.0e-9
    assert Player.stats(master).evasion - Player.stats(fighter).evasion == 3

    assert_in_delta Player.stats(shirtless.(master)).p_def -
                      Player.stats(shirtless.(fighter)).p_def,
                    14,
                    1.0e-9

    assert Player.stats(shirtless.(master)).evasion == Player.stats(shirtless.(fighter)).evasion

    # Each line adds its own, never the ones before it as well.
    adds =
      for line <- 1..3, do: Player.stats(%{master | skills: %{"Armor Mastery" => line}}).p_def

    assert Enum.map(adds, &Float.round(&1 - Player.stats(%{fighter | skills: %{}}).p_def, 1)) ==
             [9.0, 12.0, 14.0]
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
    human = character(0, :fighter, 5, %{"Power Strike" => 1, "Mortal Blow" => 1})
    gloves = %{id: "g", name: "Squire's Gloves", equipped: false}
    dagger = %{id: "d", name: "Squire's Dagger", equipped: false}
    human = %{human | items: human.items ++ [gloves, dagger]}

    {_, {:ok, warned}} = Actions.equip(human, "g")
    assert warned.type == :danger

    assert warned.text =~
             "your Mortal Blow and Power Strike skills cannot be used with a fist weapon,"

    assert {_, {:ok, %{type: :info}}} = Actions.equip(human, "d")
  end

  test "Power Strike takes a sword in either hand, and nothing else" do
    for name <- ["Squire's Sword", "Zweihander"],
        do: assert(Rules.skill_weapon?("Power Strike", Rules.item(name)), name)

    for name <- [
          "Cedar Staff",
          "Apprentice's Wand",
          "Squire's Dagger",
          "Short Bow",
          "Squire's Gloves"
        ],
        do: refute(Rules.skill_weapon?("Power Strike", Rules.item(name)), name)

    refute Rules.skill_weapon?("Power Strike", nil)
    assert Rules.skill_weapon?("Wind Strike", nil)
  end
end
