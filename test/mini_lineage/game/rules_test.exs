defmodule MiniLineage.Game.RulesTest do
  @moduledoc """
  `docs/rules.md` and the code, held together: every table in the document is read back out of it
  and compared with `Rules`, and every worked example is worked again by `Formulas`. Change one
  without the other and this fails.
  """
  use ExUnit.Case, async: true

  alias MiniLineage.Game.{Clock, Constants, Formulas, Hunt, Math, Player, Rng, Rules, Shop}

  @rules File.read!("docs/rules.md")

  # The rows of the markdown table whose header starts with `first`, as lists of trimmed cells.
  defp table(first) do
    [_, body] = String.split(@rules, "| #{first} |", parts: 2)

    body
    |> String.split("\n")
    |> Enum.drop(2)
    |> Enum.take_while(&String.starts_with?(&1, "|"))
    |> Enum.map(fn row -> row |> String.split("|", trim: true) |> Enum.map(&String.trim/1) end)
  end

  defp effect("Accuracy +" <> n), do: [accuracy: {:add, String.to_integer(n)}]

  defp effect("HP and MP per tick ×" <> n),
    do: [hp_regen: {:mul, number(n)}, mp_regen: {:mul, number(n)}]

  # A §16 row's "when it holds", as a moment and a place where it does.
  defp circumstance("at night"), do: {~U[2026-07-01 20:00:00Z], "gludio"}
  defp circumstance("in Elven Village"), do: {~U[2026-07-01 09:00:00Z], "elven-village"}

  defp number(cell), do: cell |> String.replace(",", "") |> Float.parse() |> elem(0)

  # A blank power is none; a whole number reads as an integer, as `Rules` writes it.
  defp cell(""), do: 0

  defp cell(text),
    do: if(String.contains?(text, "."), do: number(text), else: trunc(number(text)))

  defp optional(""), do: nil
  defp optional(text), do: cell(text)

  @paths %{"Fighter" => :fighter, "Mystic" => :mystic}
  @races %{"Human" => 0, "Orc" => 1, "Elf" => 2, "Dark Elf" => 3}

  describe "the tables" do
    test "§1 every race starts in its own village" do
      rows = table("Race")
      assert length(rows) == 4

      for [race, town] <- rows,
          do: assert(Rules.town(Rules.hometown(@races[race])).name == town, race)
    end

    test "§3 starting attributes are the eight sets the code starts from" do
      rows = table("Set")
      assert length(rows) == 8

      for [name, race, path | values] <- rows do
        set = Rules.set(@races[race], @paths[path])
        assert set.name == name

        assert Enum.map(values, &String.to_integer/1) ==
                 Enum.map(~w(str con dex int wit men)a, &set.attributes[&1]),
               name
      end
    end

    test "§4 the attribute curves, and the bonus each is worth at 20, 30, 40 and 50" do
      for [attr, growth, pivot | samples] <- table("Attribute"), samples != [] do
        key = attr |> String.downcase() |> String.to_existing_atom()
        assert Rules.bonus_curve(key) == {number(growth), number(pivot)}, attr

        for {value, sample} <- Enum.zip([20, 30, 40, 50], samples),
            do: assert(Formulas.bonus(key, value) == number(sample), "#{attr} #{value}")
      end
    end

    test "§6 every set's HP and MP start, gain and growth" do
      rows = table("Set | HP start")
      assert length(rows) == 8

      for [name | values] <- rows do
        set = Enum.find(Rules.sets(), &(&1.name == name))
        [hs, hg, hgr, ms, mg, mgr] = Enum.map(values, &number/1)

        assert set.hp == {hs, hg, hgr}, name
        assert set.mp == {ms, mg, mgr}, name
      end
    end

    test "§7 what each path starts with" do
      for [path, power, magic, body, mind] <- table("Path") do
        assert Rules.path(@paths[path]) ==
                 %{
                   power: trunc(number(power)),
                   magic: trunc(number(magic)),
                   body: trunc(number(body)),
                   mind: trunc(number(mind))
                 },
               path
      end
    end

    test "§14 every town, its address, whether it is open yet and its Gatekeeper" do
      rows = table("Town")
      assert length(rows) == length(Rules.towns())

      for {[name, slug, open, gatekeeper], town} <- Enum.zip(rows, Rules.towns()) do
        assert {town.name, town.slug, town.open?, town.gatekeeper} ==
                 {name, slug, open == "yes", gatekeeper},
               name
      end
    end

    test "§14 the routes, each both ways at one fee, and no others" do
      slug = fn name -> Enum.find(Rules.towns(), &(&1.name == name)).slug end
      rows = table("Between")

      written =
        for [a, b, fee] <- rows,
            {from, to} <- [{a, b}, {b, a}],
            do: {slug.(from), slug.(to), trunc(number(fee))}

      held =
        for town <- Rules.towns(),
            route <- Rules.routes_from(town.slug),
            do: {town.slug, route.to, route.fee}

      assert Enum.sort(written) == Enum.sort(held)
    end

    test "§16 every race perk with numbers: what it does, and that only its race has it" do
      for [perk, race, holds, effect] <- table("Perk") do
        key = Enum.find([:shadow_sense, :mother_tree], &(Constants.aura(&1).label == perk))
        assert key, perk
        assert Rules.modifiers(key) == effect(effect), perk

        {at, location} = circumstance(holds)
        Clock.put_now(at)

        for race_id <- 0..3 do
          {player, _} = Player.initialize(%Player{}, Constants.race(race_id), :fighter, "Kin")

          has? =
            Enum.any?(
              Player.conditions(%{player | location: location}),
              &(&1.id == to_string(key))
            )

          assert has? == (race_id == @races[race]), "#{perk} on race #{race_id}"
        end
      end
    end

    test "§17 each village's ground, its address, and its monsters in ladder order" do
      rows = table("Ground")
      assert length(rows) == length(Rules.grounds())

      for [name, town, slug, monsters] <- rows do
        ground = Rules.ground(slug)
        assert ground.name == name
        assert Rules.town(ground.town).name == town
        assert Enum.map(Rules.monsters_of(ground), & &1.name) == String.split(monsters, ", ")
      end
    end

    test "§17 every ground climbs, and starts where a new character does" do
      for ground <- Rules.grounds() do
        levels = Enum.map(Rules.monsters_of(ground), & &1.level)
        assert levels == Enum.sort(levels), ground.name
        assert hd(levels) == 1, ground.name
      end
    end

    test "§18 every monster, whole, and no other" do
      rows = table("Monster")
      assert length(rows) == map_size(Rules.monsters())

      for [
            name,
            level,
            hp,
            mp,
            p_atk,
            m_atk,
            p_def,
            m_def,
            atk_spd,
            dex,
            run_spd,
            exp,
            sp,
            adena,
            attack,
            aggressive,
            spells
          ] <-
            rows do
        m = Rules.monster(name)

        assert Enum.map(
                 [level, hp, mp, p_atk, m_atk, p_def, m_def, atk_spd, dex, run_spd, exp, sp],
                 &trunc(number(&1))
               ) ==
                 [
                   m.level,
                   m.hp,
                   m.mp,
                   m.p_atk,
                   m.m_atk,
                   m.p_def,
                   m.m_def,
                   m.atk_spd,
                   m.dex,
                   m.run_spd,
                   m.exp,
                   m.sp
                 ],
               name

        assert adena == "#{m.adena_min}–#{m.adena_max} at #{m.adena_chance}%", name
        assert spells == Enum.join(m.spells, ", "), name
        assert attack == if(m.bow?, do: "bow", else: "melee"), name
        assert aggressive == if(m.aggressive?, do: "yes", else: "no"), name
      end
    end

    test "§19 each set's first skill, known from the start, what else level 1 offers, and the rest" do
      rows = table("Set | First skill")
      assert length(rows) == 8
      names = fn cell -> cell |> String.split(", ", trim: true) |> Enum.sort() end

      for [set, first, also, then] <- rows do
        %{race_id: race, path: path} = Enum.find(Rules.sets(), &(&1.name == set))
        assert Rules.first_skill(race, path).name == first, set
        if path == :mystic, do: assert(length(names.(also)) == 1, set)

        {at_one, later} = set |> Rules.lessons() |> Enum.split_with(&(&1.learn_at == 1))
        costs = Map.new(at_one, &{&1.skill, &1.sp})
        price = if set == "Orc Fighter", do: 60, else: 50
        assert Map.pop(costs, first) == {0, Map.new(names.(also), &{&1, price})}, set
        assert Player.first_skills(race, path) == %{first => 1}, set

        rest =
          for lesson <- later,
              lesson.skill not in [first | Map.keys(costs)],
              uniq: true,
              do: lesson.skill

        assert Enum.sort(rest) == names.(then), set
      end

      names = for race <- 0..3, do: Rules.first_skill(race, :fighter).name
      assert Enum.uniq(names) == names
    end

    test "§19 every skill at level 1" do
      rows = table("Skill")
      assert length(rows) == map_size(Rules.skills())

      for [name, kind, power, mp, reuse, cast] <- rows do
        skill = Rules.skill(name)
        assert Atom.to_string(skill.kind) == kind, name
        assert [skill.power, skill.mp] == Enum.map([power, mp], &cell/1), name
        assert skill[:reuse] == optional(reuse), name
        assert skill[:cast] == optional(cast), name
        assert Rules.skill(name, 1) == skill, name
      end
    end

    test "§20 how far a blow, a bow's shot and a character's spell reach" do
      assert table("Reach") == [
               ["A blow, or a physical skill", "#{Rules.reach(:blow)}"],
               ["A bow's shot", "#{Rules.reach(:bow)}"],
               ["A character's spell", "#{Rules.reach(:spell)}"],
               ["An aggressive monster noticing a character", "#{Rules.reach(:notice)}"]
             ]
    end

    test "§10 each set's run speed" do
      rows = table("Set | Run speed")
      assert length(rows) == 8

      for [name, speed] <- rows,
          do: assert(Enum.find(Rules.sets(), &(&1.name == name)).run_spd == trunc(number(speed)))
    end

    test "§19 the spells monsters cast, and every one a monster carries is among them" do
      rows = table("Spell")
      assert length(rows) == map_size(Rules.monster_spells())

      for [name, kind, power, mp, reuse, cast, range] <- rows do
        spell = Rules.monster_spell(name)
        assert Atom.to_string(spell.kind) == kind

        assert [spell.power, spell.mp, spell.reuse, spell.cast, spell.range] ==
                 Enum.map([power, mp, reuse, cast, range], &trunc(number(&1)))
      end

      for {_, m} <- Rules.monsters(), spell <- m.spells, do: Rules.monster_spell(spell)
    end

    test "§7 what each of the three pieces stands for, adding up to what each path starts with" do
      cell = fn
        "" -> nil
        v -> trunc(number(v))
      end

      for [part, fighter, mystic, mind, light, robe, jewel] <- table("Part") do
        p = Rules.part(part |> String.downcase() |> String.to_existing_atom())

        assert [p.fighter, p.mystic, p.mind, p[:light], p[:magic], p[:jewel]] ==
                 Enum.map([fighter, mystic, mind, light, robe, jewel], cell),
               part
      end

      total = fn key -> Enum.sum(for {_, part} <- Rules.parts(), do: part[key]) end
      assert total.(:fighter) + 4 == Rules.path(:fighter).body
      assert total.(:mystic) + 4 == Rules.path(:mystic).body
      assert total.(:mind) == Rules.path(:fighter).mind
    end

    test "§23 every set's kit, the wearable part equipped, every piece an item" do
      rows = table("Kit")
      assert length(rows) == 8

      for [set, equipped, carried] <- rows do
        %{race_id: race, path: path} = Enum.find(Rules.sets(), &(&1.name == set))
        names = fn cell -> String.split(cell, ", ", trim: true) end
        assert Rules.kit(race, path) == {names.(equipped), names.(carried)}, set
        for name <- names.(equipped) ++ names.(carried), do: assert(Rules.item?(name), name)
      end
    end

    test "§23 a character carries as many items as the document says, a kit leaving room" do
      assert @rules =~ "carries up to #{Rules.capacity()} items"

      for %{race_id: race, path: path, name: set} <- Rules.sets() do
        {equipped, carried} = Rules.kit(race, path)
        assert length(equipped) + length(carried) < Rules.capacity(), set
      end
    end

    test "§23 every set starts holding what its first skill needs" do
      for %{race_id: race, path: path, name: set} <- Rules.sets() do
        {player, _} = Player.initialize(%Player{}, Constants.race(race), path, "Novice")
        weapon = Enum.find(Player.equipped(player), &(&1.slot == :weapon))

        assert [skill] = Map.keys(player.skills), set
        assert Rules.skill_weapon?(skill, weapon), set
      end
    end

    test "§24 a kit holds only what no shop sells, and only a kit holds it" do
      kits =
        for %{race_id: race, path: path} <- Rules.sets(),
            {equipped, carried} = Rules.kit(race, path),
            name <- equipped ++ carried,
            uniq: true,
            do: name

      starting = for {name, %{sold: :starting}} <- Rules.items(), do: name
      assert Enum.sort(kits) == Enum.sort(starting)
    end

    test "§26 every potion, and no other" do
      rows = table("Potion")
      assert length(rows) == map_size(Rules.potions())

      for [name, heals, price, sold] <- rows do
        potion = Rules.item(name)
        assert Rules.stacks?(potion)
        assert {potion.heals, potion.price} == {String.to_integer(heals), trunc(number(price))}
        assert Atom.to_string(potion.sold) == sold
      end
    end

    test "§24 every item, whole, and no other" do
      rows = table("Item")
      assert length(rows) == map_size(Rules.items())

      cell = fn
        "" -> nil
        v -> trunc(number(v))
      end

      for [
            name,
            kind,
            slot,
            hands,
            type,
            p_atk,
            m_atk,
            atk_spd,
            critical,
            accuracy,
            spread,
            p_def,
            m_def,
            shield,
            block,
            mp,
            price,
            sold
          ] <- rows do
        item = Rules.item(name)

        assert [
                 Atom.to_string(item.kind),
                 Atom.to_string(item.slot),
                 item.type || "",
                 Atom.to_string(item.sold)
               ] ==
                 [kind, slot, type, sold],
               name

        assert [
                 item.hands,
                 item.p_atk,
                 item.m_atk,
                 item.atk_spd,
                 item.critical,
                 item.accuracy,
                 item.spread,
                 item.p_def,
                 item.m_def,
                 item.shield_def,
                 item.shield_rate,
                 item.mp,
                 item.price
               ] ==
                 Enum.map(
                   [
                     hands,
                     p_atk,
                     m_atk,
                     atk_spd,
                     critical,
                     accuracy,
                     spread,
                     p_def,
                     m_def,
                     shield,
                     block,
                     mp,
                     price
                   ],
                   cell
                 ),
               name
      end
    end

    test "§25 every set's guild and its trainers" do
      rows = table("Set | Guild")
      assert Enum.map(rows, &hd/1) == Enum.map(Rules.sets(), & &1.name)

      for [set, guild, trainers] <- rows do
        assert Rules.guild(set) == %{name: guild, trainers: String.split(trainers, ", ")}, set
      end
    end

    test "§25 every set's lessons, and no others" do
      rows = table("Set | Skill")

      assert length(rows) ==
               Enum.sum(for set <- Rules.sets(), do: length(Rules.lessons(set.name)))

      for [set, skill, level, from, sp] <- rows do
        assert %{learn_at: learn_at, sp: cost} =
                 Enum.find(
                   Rules.lessons(set),
                   &(&1.skill == skill and &1.level == String.to_integer(level))
                 ),
               "#{set} #{skill} #{level}"

        assert {learn_at, cost} == {String.to_integer(from), trunc(number(sp))}
      end
    end

    test "§25 every skill's power and MP at each level" do
      for [name_level, power, mp] <- table("Skill level") do
        [_, name, level] = Regex.run(~r/^(.+) (\d+)$/, name_level)
        skill = Rules.skill(name, String.to_integer(level))
        assert {skill.power, skill.mp} == {cell(power), cell(mp)}, name_level
      end

      for {name, _} <- Rules.skills() do
        assert length(Rules.skill_levels(name)) ==
                 length(
                   Enum.filter(table("Skill level"), &String.starts_with?(hd(&1), name <> " "))
                 )
      end
    end

    test "§12 the EXP for every level, 1 to 80" do
      written =
        table("Levels")
        |> Enum.flat_map(fn [_, values] -> String.split(values, ", ") end)
        |> Enum.map(&String.to_integer/1)

      assert written == Enum.map(1..80, &Rules.experience/1)
      assert Rules.max_level() == 80
      assert Enum.map(1..80, &Math.xp_for_level/1) == written
    end
  end

  describe "the worked examples" do
    test "§1 a new character starts at level 1 with no Adena" do
      for race <- Constants.races(), path <- [:fighter, :mystic] do
        {player, _} = Player.initialize(%Player{}, race, path, "Newborn")

        assert Math.level_for_xp(player.experience) == 1
        assert player.adena == 0
      end
    end

    setup do
      %{hf: Rules.set(0, :fighter), hm: Rules.set(0, :mystic)}
    end

    test "§4 and §5", %{hf: hf} do
      assert Formulas.bonus(:str, hf.attributes.str) == 1.20
      assert Formulas.level_bonus(1) == 0.90
      assert Formulas.level_bonus(80) == 1.69
    end

    test "§6 a Human Fighter's Max HP at 1, 20, 40 and 80", %{hf: hf} do
      hp = fn level -> Formulas.max_hp(Formulas.grown(hf.hp, level), hf.attributes.con) end

      assert Formulas.grown(hf.hp, 20) == 327
      assert Enum.map([1, 20, 40, 80], hp) == [126, 516, 1007, 2235]
    end

    test "§7 power, at level 1", %{hf: hf, hm: hm} do
      fighter = Rules.path(:fighter)

      assert_in_delta Formulas.p_atk(fighter.power, hf.attributes.str, 1), 4.32, 1.0e-9
      assert_in_delta Formulas.p_def(fighter.body, 1), 72.0, 1.0e-9
      assert_in_delta Formulas.m_def(fighter.mind, hf.attributes.men, 1), 47.2, 0.05
      assert_in_delta Formulas.m_atk(Rules.path(:mystic).magic, hm.attributes.int, 1), 7.1, 0.05
    end

    test "§8 Accuracy and Evasion", %{hf: hf} do
      assert Formulas.accuracy(hf.attributes.dex, 1) == 34
      assert Formulas.evasion(hf.attributes.dex, 1) == 34
    end

    test "§9 Critical and Magic Critical, and their caps", %{hf: hf, hm: hm} do
      assert_in_delta Formulas.critical(hf.attributes.dex), 4.4, 1.0e-9
      assert_in_delta Formulas.magic_critical(hm.attributes.wit), 0.8, 1.0e-9
      # DEX alone never reaches the 50% cap; it is there for what later systems add.
      assert Formulas.caps().critical == 50
      assert Formulas.magic_critical(99) == 20
    end

    test "§10 speed, blows a round, and the caps", %{hf: hf} do
      assert Formulas.atk_spd(hf.attributes.dex) == 330
      assert_in_delta Formulas.blows_per_round(330), 1.1, 1.0e-9
      assert Formulas.casts_per_round(333) == 1.0
      assert Formulas.atk_spd(99) <= 1500
      assert Formulas.cast_spd(99) == 1999
      assert Formulas.run_spd(hf.attributes.dex, hf.run_spd) == 126
    end

    test "§11 resting: 18 ticks to full at level 1, 31 at 40, in whole points", %{hf: hf} do
      con = hf.attributes.con
      assert_in_delta Formulas.hp_regen(1, con), 6.6, 0.05
      assert_in_delta Formulas.hp_regen(40, con), 33.0, 0.05

      # What a tick actually restores is the rounded rate, which `Player.auras/1` carries.
      {player, _} = Player.initialize(%Player{}, Constants.race(0), :fighter, "Rester")
      assert [hp_regen: 7] = Enum.find(Player.auras(%{player | health: 1}), & &1[:rates]).rates

      ticks = fn level, max -> ceil(max / Math.js_round(Formulas.hp_regen(level, con))) end
      assert ticks.(1, 126) == 18
      assert ticks.(40, 1007) == 31
    end

    test "§14 the villages never link to each other, only to Gludio" do
      for race_id <- 0..3, route <- Rules.routes_from(Rules.hometown(race_id)) do
        assert route.to == "gludio"
      end
    end

    test "§14 an Elf reaches Dion for 7,800, and an Orc with 10,000 cannot" do
      fee = fn from, to -> Rules.route(from, to).fee end

      assert fee.("elven-village", "gludio") + fee.("gludio", "dion") == 7_800
      assert 10_000 - fee.("orc-village", "gludio") == 4_000
      assert 4_000 < fee.("gludio", "dion")
    end

    test "§15 a Human Fighter's Accuracy at night, and §16 a Dark Fighter's" do
      accuracy = fn race_id, at ->
        Clock.put_now(at)
        {player, _} = Player.initialize(%Player{}, Constants.race(race_id), :fighter, "Sentry")
        Player.stats(player).accuracy
      end

      assert accuracy.(0, ~U[2026-07-01 09:00:00Z]) == 34
      assert accuracy.(0, ~U[2026-07-01 20:00:00Z]) == 31
      assert accuracy.(3, ~U[2026-07-01 09:00:00Z]) == 33
      assert accuracy.(3, ~U[2026-07-01 20:00:00Z]) == 33
      assert Rules.modifiers(:night) == [accuracy: {:add, -3}]
    end

    test "§16 a level 1 Elven Fighter rests 5 HP and 3 MP, and 8 and 5 beneath the Mother Tree" do
      Clock.put_now(~U[2026-07-01 09:00:00Z])
      {elf, _} = Player.initialize(%Player{}, Constants.race(2), :fighter, "Sapling")

      rates = fn location ->
        Player.auras(%{elf | location: location, health: 1, mp: 0}) |> List.last()
      end

      assert_in_delta Player.stats(%{elf | location: "gludio"}).hp_regen, 5.36, 0.005
      assert_in_delta Player.stats(%{elf | location: "gludio"}).mp_regen, 3.16, 0.005
      assert rates.("gludio").rates == [hp_regen: 5, mp_regen: 3]
      assert rates.("elven-village").rates == [hp_regen: 8, mp_regen: 5]
    end

    test "§18 a Young Keltir's Accuracy, Evasion and Critical" do
      keltir = Hunt.foe(Rules.monster("Young Keltir"))
      assert {keltir.accuracy, keltir.evasion} == {34, 34}
      assert_in_delta keltir.critical, 4.4, 1.0e-9
    end

    test "§19 Power Strike against a blow, Mortal Blow's chance, and a skill's reuse" do
      Clock.put_now(~U[2026-07-01 09:00:00Z])
      {fighter, _} = Player.initialize(%Player{}, Constants.race(0), :fighter, "Squire")
      stats = Player.stats(fighter)
      assert_in_delta stats.p_atk, 6.48, 1.0e-9
      assert_in_delta Hunt.skill_damage(stats.p_atk, 25, 39, 1.0), 56.5, 0.05
      assert_in_delta Formulas.physical_damage(stats.p_atk, 39), 11.6, 0.05
      assert_in_delta Hunt.blow_chance(34), 45.6, 1.0e-9
      assert stats.atk_spd == 416
      assert round(13_000 * 333 / 416) == 10_406
    end

    test "§20 EXP shrinks by 5/6 a level past the fifth, and not before" do
      assert Hunt.reward(:exp, 35, 12, 1) == 58
      assert Hunt.reward(:exp, 35, 6, 1) == 175
    end

    test "§22 the server's rates, and a Young Keltir's 10 Adena paying 200" do
      for [kind, times] <- table("Rate") do
        assert Rules.rate(kind |> String.downcase() |> String.to_existing_atom()) ==
                 String.to_integer(times)
      end

      Rng.put_source(fn -> 0.5 end)
      assert Hunt.adena(%{adena_chance: 100, adena_min: 10, adena_max: 10}) == 200
    end

    test "§21 a level 9 run with 40,000 EXP stands above every level 8 run and a 39,999 one" do
      assert Math.level_for_xp(40_000) == 9
      assert Math.level_for_xp(39_999) == 9
      assert Math.level_for_xp(Math.xp_for_level(9) - 1) == 8
    end

    test "§7 a Human Fighter in its starting kit" do
      Clock.put_now(~U[2026-07-01 09:00:00Z])
      {fighter, _} = Player.initialize(%Player{}, Constants.race(0), :fighter, "Squire")
      stats = Player.stats(fighter)

      assert_in_delta stats.p_atk, 6.48, 1.0e-9
      assert_in_delta stats.p_def, 77.5, 0.05
      assert_in_delta Rules.counts_for(Rules.item("Necklace of Wisdom")), 78.8, 0.05
    end

    test "§9 and §10 a sword's critical and speed, and an Elven Fighter's Squire's Bow" do
      Clock.put_now(~U[2026-07-01 09:00:00Z])
      {fighter, _} = Player.initialize(%Player{}, Constants.race(0), :fighter, "Squire")
      {elf, _} = Player.initialize(%Player{}, Constants.race(2), :fighter, "Archer")

      assert_in_delta Player.stats(fighter).critical, 8.8, 1.0e-9
      assert Player.stats(fighter).atk_spd == 416
      assert Player.stats(elf).atk_spd == 336
      assert_in_delta Player.stats(elf).blows_per_round, 0.55, 0.005
    end

    test "§23 a Small Shield catches 22% at DEX 30, and a Mystic's robes add 29 MP" do
      Clock.put_now(~U[2026-07-01 09:00:00Z])
      assert_in_delta Hunt.block_chance(20, 30), 22.0, 1.0e-9

      {mystic, _} = Player.initialize(%Player{}, Constants.race(0), :mystic, "Novice")
      bare = %{mystic | items: []}
      assert Player.stats(mystic).max_mp - Player.stats(bare).max_mp == 29
    end

    test "§26 a Lesser Healing Potion lifts 100 of 280 HP to 212, and ten cost 900" do
      potion = Rules.item("Lesser Healing Potion")
      assert min(100 + potion.heals, 280) == 212
      assert Shop.price(potion) * 10 == 900
    end

    test "§19 Self Heal at 20 M.Atk mends 46" do
      assert MiniLineage.Game.Hunt.heal_amount(42, 20) == 46
    end

    test "§24 each village's four traders" do
      rows = table("Village | Weapons Trader")
      assert length(rows) == length(Enum.filter(Rules.towns(), &Rules.village?(&1.slug)))

      for [village, weapons, armour, jewellery, grocer] <- rows do
        slug = Enum.find(Rules.towns(), &(&1.name == village)).slug

        assert Rules.traders(slug) ==
                 %{weapons: weapons, armour: armour, jewellery: jewellery, grocer: grocer},
               village
      end
    end

    test "§24 a trader shows each path its own goods, and every shield, necklace and potion" do
      weapons = fn set ->
        for i <- Rules.stock("orc-village", set), i.slot == :weapon, uniq: true, do: i.type
      end

      robes = fn set ->
        for i <- Rules.stock("orc-village", set),
            i.slot in [:chest, :legs],
            uniq: true,
            do: i.type
      end

      shared = fn set ->
        for i <- Rules.stock("orc-village", set),
            i.slot in [:shield, :necklace, :potion],
            do: i.name
      end

      everyone =
        for i <- Rules.stock("orc-village"), i.slot in [:shield, :necklace, :potion], do: i.name

      for {set, types} <- [
            {"Human Fighter", ["bow", "dagger", "sword"]},
            {"Elven Fighter", ["bow"]},
            {"Dark Fighter", ["dagger"]},
            {"Orc Fighter", ["fists", "sword"]}
          ],
          set = Enum.find(Rules.sets(), &(&1.name == set)) do
        assert Enum.sort(weapons.(set)) == types, set.name
        assert robes.(set) == ["light"], set.name
        assert shared.(set) == everyone, set.name
      end

      for set <- Rules.sets(), set.path == :mystic do
        assert weapons.(set) == ["staff"], set.name
        assert robes.(set) == ["magic"], set.name
        assert shared.(set) == everyone, set.name
      end
    end

    test "§24 a Broadsword costs 12,500 and sells back for 6,250" do
      assert Shop.price(Rules.item("Broadsword")) == 12_500
      assert Shop.buyback(Rules.item("Broadsword")) == 6_250
    end

    test "§25 a Human Fighter knows Power Strike 1, buys Mortal Blow 1 at level 1 and Power Strike 2 at 5" do
      Clock.put_now(~U[2026-07-01 09:00:00Z])
      {fighter, _} = Player.initialize(%Player{}, Constants.race(0), :fighter, "Pupil")
      assert fighter.skills == %{"Power Strike" => 1}

      {fighter, {:ok, _}} =
        MiniLineage.Game.Actions.learn(%{fighter | sp: 50}, "Mortal Blow", 1)

      assert fighter.sp == 0

      assert {_, {:error, :too_soon, _}} =
               MiniLineage.Game.Actions.learn(%{fighter | sp: 150}, "Power Strike", 2)

      fighter = %{fighter | experience: Math.xp_for_level(5), sp: 150}
      {fighter, {:ok, _}} = MiniLineage.Game.Actions.learn(fighter, "Power Strike", 2)

      assert fighter.sp == 50
      assert Rules.skill("Power Strike", fighter.skills["Power Strike"]).power == 30

      {mystic, _} = Player.initialize(%Player{}, Constants.race(0), :mystic, "Pupil")
      assert mystic.skills == %{"Wind Strike" => 1}
      {mystic, {:ok, _}} = MiniLineage.Game.Actions.learn(%{mystic | sp: 50}, "Self Heal", 1)
      assert mystic.sp == 0
    end

    test "§8 Squire's Gloves' +4 Accuracy, and §13 a weapon's spread and bare hands'" do
      Clock.put_now(~U[2026-07-01 09:00:00Z])
      {fighter, _} = Player.initialize(%Player{}, Constants.race(0), :fighter, "Squire")
      gloves = %{fighter | items: [%{id: "g", name: "Squire's Gloves", equipped: true}]}
      wand = %{fighter | items: [%{id: "w", name: "Apprentice's Wand", equipped: true}]}

      assert Player.stats(gloves).accuracy == 38
      assert Player.stats(wand).spread == 20
      assert Player.stats(%{fighter | items: []}).spread == 6
      Rng.put_source(fn -> 0.0 end)
      assert Formulas.damage_spread(20) == 0.8
    end

    test "§13 hit chance, inside 28% and 98%" do
      assert Formulas.hit_chance(40, 34) == 98
      assert Formulas.hit_chance(34, 34) == 88
      assert Formulas.hit_chance(0, 100) == 28
    end

    test "§13 damage, physical and magic, with their criticals" do
      assert Formulas.physical_damage(100, 70) == 100.0
      assert Formulas.physical_damage(100, 70, critical: true) == 200.0
      assert_in_delta Formulas.physical_damage(100, 70, spread: 0.9), 90.0, 1.0e-9
      assert Formulas.physical_damage(1, 10_000) == 1.0

      assert_in_delta Formulas.magic_damage(100, 91, 10), 100.0, 1.0e-9
      assert_in_delta Formulas.magic_damage(100, 91, 10, critical: true), 400.0, 1.0e-9
    end

    test "§13 the rolls, with the source pinned" do
      Rng.put_source(fn -> 0.0 end)
      assert Formulas.damage_spread() == 0.9
      Rng.put_source(fn -> 0.9999 end)
      assert Formulas.damage_spread() == 1.1
      refute Formulas.hit?(50)
      assert Formulas.hit?(100)
    end
  end
end
