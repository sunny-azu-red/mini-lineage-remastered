defmodule MiniLineage.Game.Rules do
  @moduledoc """
  The base layer's tables, exactly as `docs/rules.md` writes them: the eight starting sets, what
  each path starts with, the attribute bonus curves, the EXP each level needs, the towns and the
  routes between them, and what night and the race perks do. `rules_test.exs`
  reads the tables back out of the document, so the two cannot disagree.
  """

  # Rules §3, §6 and §10: each set's attributes, its HP and MP as {start, gain, growth}, and the run
  # speed its DEX bonus multiplies.
  @sets [
    %{
      race_id: 0,
      path: :fighter,
      name: "Human Fighter",
      run_spd: 115,
      attributes: %{str: 40, con: 43, dex: 30, int: 21, wit: 11, men: 25},
      hp: {80.0, 11.83, 0.13},
      mp: {30.0, 5.46, 0.06}
    },
    %{
      race_id: 0,
      path: :mystic,
      name: "Human Mystic",
      run_spd: 120,
      attributes: %{str: 22, con: 27, dex: 21, int: 41, wit: 20, men: 39},
      hp: {101.0, 15.47, 0.17},
      mp: {40.0, 7.28, 0.08}
    },
    %{
      race_id: 2,
      path: :fighter,
      name: "Elven Fighter",
      run_spd: 125,
      attributes: %{str: 36, con: 36, dex: 35, int: 23, wit: 14, men: 26},
      hp: {89.0, 12.74, 0.14},
      mp: {30.0, 5.46, 0.06}
    },
    %{
      race_id: 2,
      path: :mystic,
      name: "Elven Mystic",
      run_spd: 122,
      attributes: %{str: 21, con: 25, dex: 24, int: 37, wit: 23, men: 40},
      hp: {104.0, 15.47, 0.17},
      mp: {40.0, 7.28, 0.08}
    },
    %{
      race_id: 3,
      path: :fighter,
      name: "Dark Fighter",
      run_spd: 122,
      attributes: %{str: 41, con: 32, dex: 34, int: 25, wit: 12, men: 26},
      hp: {94.0, 13.65, 0.15},
      mp: {30.0, 5.46, 0.06}
    },
    %{
      race_id: 3,
      path: :mystic,
      name: "Dark Mystic",
      run_spd: 122,
      attributes: %{str: 23, con: 24, dex: 23, int: 44, wit: 19, men: 37},
      hp: {106.0, 15.47, 0.17},
      mp: {40.0, 7.28, 0.08}
    },
    %{
      race_id: 1,
      path: :fighter,
      name: "Orc Fighter",
      run_spd: 117,
      attributes: %{str: 40, con: 47, dex: 26, int: 18, wit: 12, men: 27},
      hp: {80.0, 12.74, 0.14},
      mp: {30.0, 5.46, 0.06}
    },
    %{
      race_id: 1,
      path: :mystic,
      name: "Orc Mystic",
      run_spd: 121,
      attributes: %{str: 27, con: 31, dex: 24, int: 31, wit: 15, men: 42},
      hp: {95.0, 15.47, 0.17},
      mp: {40.0, 7.28, 0.08}
    }
  ]

  # Rules §14: every town, by the slug its address is made of. One not yet open is only listed.
  @towns [
    %{slug: "talking-island", name: "Talking Island Village", emoji: "🏝️", open?: true},
    %{slug: "elven-village", name: "Elven Village", emoji: "🌳", open?: true},
    %{slug: "dark-elf-village", name: "Dark Elf Village", emoji: "🌑", open?: true},
    %{slug: "orc-village", name: "Orc Village", emoji: "🏕️", open?: true},
    %{slug: "gludio", name: "Town of Gludio", emoji: "🏰", open?: true},
    %{slug: "dion", name: "Town of Dion", emoji: "🌾", open?: true},
    %{slug: "giran", name: "Town of Giran", emoji: "🐉", open?: false},
    %{slug: "giran-harbor", name: "Giran Harbor", emoji: "⚓", open?: false}
  ]

  # Rules §1: the village each race starts in.
  @hometowns %{
    0 => "talking-island",
    1 => "orc-village",
    2 => "elven-village",
    3 => "dark-elf-village"
  }

  # Rules §14: each route runs both ways at one fee, listed in the order a Gatekeeper reads them.
  @routes [
    {"gludio", "dion", 4_100},
    {"talking-island", "gludio", 2_900},
    {"elven-village", "gludio", 3_700},
    {"dark-elf-village", "gludio", 3_700},
    {"orc-village", "gludio", 6_000},
    {"dion", "giran", 8_100},
    {"dion", "giran-harbor", 6_500}
  ]

  # Rules §15 and §16: what each condition the world puts on a character does to its stats.
  @modifiers %{
    night: [accuracy: {:add, -3}],
    shadow_sense: [accuracy: {:add, 3}],
    mother_tree: [hp_regen: {:mul, 1.5}, mp_regen: {:mul, 1.5}]
  }

  # Rules §7: what a path starts with before anything is added to it.
  @paths %{
    fighter: %{power: 4, magic: 6, body: 80, mind: 41},
    mystic: %{power: 3, magic: 6, body: 54, mind: 41}
  }

  # Rules §7: what each of the three pieces stands for, as its part's share of the body (fighter,
  # mystic) or of the mind, and the slot's own share in Lineage II, light armour by the fighter's
  # and a robe by the mystic's.
  @parts %{
    chest: %{fighter: 51, mystic: 35, mind: 0, light: 31, magic: 15},
    legs: %{fighter: 25, mystic: 15, mind: 0, light: 18, magic: 8},
    necklace: %{fighter: 0, mystic: 0, mind: 41, jewel: 13}
  }

  # Rules §4: each attribute's {growth, pivot}.
  @bonus %{
    str: {1.036, 34.845},
    con: {1.030, 27.632},
    dex: {1.009, 19.36},
    int: {1.020, 31.375},
    wit: {1.050, 20.0},
    men: {1.010, -0.06}
  }

  # Rules §12: the EXP a character needs to reach each level, 1 to 80.
  @experience [
    0,
    68,
    363,
    1168,
    2884,
    6038,
    11_287,
    19_423,
    31_378,
    48_229,
    71_201,
    101_676,
    141_192,
    191_452,
    254_327,
    331_864,
    426_284,
    539_995,
    675_590,
    835_854,
    1_023_775,
    1_242_536,
    1_495_531,
    1_786_365,
    2_118_860,
    2_497_059,
    2_925_229,
    3_407_873,
    3_949_727,
    4_555_766,
    5_231_213,
    5_981_539,
    6_812_472,
    7_729_999,
    8_740_372,
    9_850_111,
    11_066_012,
    12_395_149,
    13_844_879,
    15_422_851,
    17_137_002,
    18_995_573,
    21_007_103,
    23_180_442,
    25_524_751,
    28_049_509,
    30_764_519,
    33_679_907,
    36_806_133,
    40_153_995,
    45_524_865,
    51_262_204,
    57_383_682,
    63_907_585,
    70_852_742,
    80_700_339,
    91_162_131,
    102_265_326,
    114_038_008,
    126_509_030,
    146_307_211,
    167_243_291,
    189_363_788,
    212_716_741,
    237_351_413,
    271_973_532,
    308_441_375,
    346_825_235,
    387_197_529,
    429_632_402,
    474_205_751,
    532_692_055,
    606_319_094,
    696_376_867,
    804_219_972,
    931_275_828,
    1_151_275_834,
    1_511_275_834,
    2_099_275_834,
    4_200_000_000
  ]

  # Rules §17: one ground per starting village, its monsters a ladder by level.
  @grounds [
    %{
      slug: "obelisk-of-victory",
      name: "Obelisk of Victory",
      town: "talking-island",
      monsters:
        ~w(Young_Keltir Bearded_Keltir Elpy Gremlin Elder_Keltir Wolf Elder_Wolf Giant_Toad Orc
           Orc_Grunt Goblin_Scout Orc_Archer Werewolf Orc_Fighter Werewolf_Hunter Orc_Lieutenant
           Werewolf_Chieftain Orc_Fighter_Leader Stone_Golem Crasher Talon_Spider Blade_Spider)
    },
    %{
      slug: "elven-fortress",
      name: "Elven Fortress",
      town: "elven-village",
      monsters:
        ~w(Young_Red_Keltir Gremlin Red_Keltir Elder_Red_Keltir Gray_Wolf Goblin_Raider Kaboo_Orc
           Kaboo_Orc_Grunt Green_Dryad Kaboo_Orc_Archer Spore_Fungus Kaboo_Orc_Fighter
           Baraq_Orc_Fighter Baraq_Orc_Warrior_Leader Dungeon_Skeleton Dungeon_Skeleton_Archer
           Dread_Soldier Mist_Terror Dark_Terror Shade_Horror Sukar_Wererat Sukar_Wererat_Leader
           Dre_Vanul_Tracker)
    },
    %{
      slug: "school-of-dark-arts",
      name: "School of Dark Arts",
      town: "dark-elf-village",
      monsters:
        ~w(Young_Brown_Keltir Gremlin Brown_Keltir Elder_Brown_Keltir Ashen_Wolf Goblin Imp
           Imp_Elder Balor_Orc_Archer Goblin_Lookout Green_Fungus Balor_Orc_Fighter Goblin_Thief
           Vaiss_Orc Balor_Orc_Lieutenant Vaiss_Orc_Warrior_Leader Balor_Orc_Fighter_Leader
           Blood_Fungus Skeleton_Hunter Doom_Soldier Cave_Spider Cave_Fang_Spider Omen_Beast
           Tainted_Zombie Stink_Zombie Lesser_Succubus Lesser_Succubus_Turen Lesser_Succubus_Tilfo)
    },
    %{
      slug: "cave-of-trials",
      name: "Cave of Trials",
      town: "orc-village",
      monsters: ~w(Young_Prairie_Keltir Gremlin Prairie_Keltir Elder_Prairie_Keltir Kasha_Wolf
           Goblin_Grave_Robber Rakeclaw_Imp Kasha_Timber_Wolf Rakeclaw_Imp_Hunter Mountain_Fungus
           Maraku_Werewolf Evil_Eye Evil_Eye_Watcher Darkwing_Bat Grizzly Goblin_Tomb_Raider_Leader
           Slave_Skeleton Greystone_Golem Grave_Keeper Evil_Eye_Patroller Crypt_Horror Kuruka_Ratman
           Kuruka_Ratman_Hunter Skeleton_Longbowman Undead_Slave Ghost Ghost_Guardian)
    }
  ]

  # Rules §18, a table in the hundreds and so a data file, read here at compile time.
  @external_resource monsters_path = Path.join(:code.priv_dir(:mini_lineage), "game/monsters.csv")
  @monsters (
              [header | rows] =
                monsters_path |> File.read!() |> String.split("\n", trim: true)

              keys =
                ~w(name level hp mp p_atk m_atk p_def m_def atk_spd dex run_spd exp sp adena_min
                   adena_max adena_chance attack aggressive spells)a

              ^header = Enum.join(keys, ",")

              for row <- rows, into: %{} do
                monster = keys |> Enum.zip(String.split(row, ",")) |> Map.new()
                numbers = Map.drop(monster, [:name, :spells, :adena_chance, :attack, :aggressive])

                monster =
                  numbers
                  |> Map.new(fn {k, v} -> {k, String.to_integer(v)} end)
                  |> Map.merge(%{
                    name: monster.name,
                    adena_chance: String.to_integer(monster.adena_chance),
                    bow?: monster.attack == "bow",
                    aggressive?: monster.aggressive == "yes",
                    spells: String.split(monster.spells, "; ", trim: true)
                  })

                {monster.name, monster}
              end
            )

  # Rules §19: every skill a set learns before its class change, at level 1. Times in milliseconds.
  @skills %{
    "Power Strike" => %{kind: :physical, power: 25, mp: 10, reuse: 13_000},
    "Power Shot" => %{kind: :physical, power: 65, mp: 19, reuse: 25_000},
    "Mortal Blow" => %{kind: :blow, power: 73, mp: 9, reuse: 11_000},
    "Iron Punch" => %{kind: :physical, power: 29, mp: 11, reuse: 15_000},
    "Wind Strike" => %{kind: :magic, power: 12, mp: 9, reuse: 6_000, cast: 4_000},
    "Ice Bolt" => %{kind: :magic, power: 9, mp: 10, reuse: 8_000, cast: 3_300, slow: true},
    "Vampiric Touch" => %{
      kind: :drain,
      power: 21,
      mp: 28,
      reuse: 12_000,
      cast: 4_000,
      absorb: 0.4
    },
    "Chill Flame" => %{kind: :burn, power: 20, mp: 15, reuse: 6_000, cast: 4_000},
    "Drain Health" => %{
      kind: :drain,
      power: 22,
      mp: 13,
      reuse: 15_000,
      cast: 3_000,
      absorb: 0.2
    },
    "Life Drain" => %{kind: :drain, power: 15, mp: 27, reuse: 6_000, cast: 4_000, absorb: 0.8},
    "Self Heal" => %{kind: :heal, power: 42, mp: 9, reuse: 10_000, cast: 5_000},
    "Heal" => %{kind: :heal, power: 67, mp: 14, reuse: 10_000, cast: 5_000},
    "Elemental Heal" => %{kind: :heal, power: 80, mp: 45, reuse: 10_000, cast: 5_000},
    "Defense Aura" => %{
      kind: :aura,
      power: 0,
      mp: 5,
      reuse: 6_000,
      cast: 4_000,
      stat: :p_def,
      times: 1.08,
      lasts: 120_000
    },
    "Attack Aura" => %{
      kind: :aura,
      power: 0,
      mp: 7,
      reuse: 6_000,
      cast: 4_000,
      stat: :p_atk,
      times: 1.08,
      lasts: 120_000
    },
    # Rules §19: a buff Lineage II cast on a target, here always the caster itself.
    "Shield" => %{
      kind: :aura,
      power: 0,
      mp: 10,
      reuse: 6_000,
      cast: 4_000,
      stat: :p_def,
      times: 1.08,
      lasts: 120_000
    },
    "Soul Shield" => %{
      kind: :aura,
      power: 0,
      mp: 10,
      reuse: 5_000,
      cast: 2_500,
      stat: :p_def,
      times: 1.08,
      lasts: 120_000
    },
    "Curse: Poison" => %{
      kind: :poison,
      power: 24,
      mp: 10,
      reuse: 12_000,
      cast: 4_000,
      land: 70,
      every: 3_000,
      lasts: 30_000
    },
    "Wind Shackle" => %{
      kind: :shackle,
      power: 0,
      mp: 3,
      reuse: 8_000,
      cast: 1_500,
      land: 80,
      times: 0.83,
      lasts: 15_000
    },
    # A toggle's MP is to light it; it then drains `drain` MP every `every` until the MP runs out.
    "Soul Cry" => %{kind: :toggle, power: 4.5, mp: 2, drain: 3, every: 3_000},
    # Rules §11: power HP more on each tick of rest, for MP each tick.
    "Relax" => %{kind: :rest, power: 5, mp: 3}
  }

  # Rules §25: each skill's {power, MP} by level, level 1 first; a burn's power is per second, and a
  # toggle's level says what it drains as well.
  @skill_levels %{
    "Power Strike" => [{25, 10}, {30, 11}, {46, 14}, {70, 19}],
    "Mortal Blow" => [{73, 9}, {88, 10}, {137, 13}, {210, 17}],
    "Power Shot" => [{65, 19}, {78, 21}, {122, 27}, {187, 37}],
    "Iron Punch" => [{29, 11}, {34, 13}, {54, 16}, {82, 22}],
    "Wind Strike" => [{12, 9}, {15, 10}, {21, 15}],
    "Ice Bolt" => [{9, 10}, {13, 15}],
    "Vampiric Touch" => [{21, 28}],
    "Chill Flame" => [{20, 15}, {30, 23}],
    "Drain Health" => [{22, 13}],
    "Life Drain" => [{15, 27}, {21, 40}],
    "Self Heal" => [{42, 9}],
    "Heal" => [{67, 14}, {107, 22}],
    "Elemental Heal" => [{80, 45}],
    "Defense Aura" => [{0, 5}],
    "Attack Aura" => [{0, 7}],
    "Shield" => [{0, 10}],
    "Soul Shield" => [{0, 10}],
    "Curse: Poison" => [{24, 10}],
    "Wind Shackle" => [{0, 3}],
    "Soul Cry" => [%{power: 4.5, mp: 2, drain: 3}, %{power: 14, mp: 3, drain: 6}],
    "Relax" => [{5, 3}]
  }

  @first_skills %{
    {0, :fighter} => "Power Strike",
    {2, :fighter} => "Power Shot",
    {3, :fighter} => "Mortal Blow",
    {1, :fighter} => "Iron Punch",
    {0, :mystic} => "Wind Strike",
    {2, :mystic} => "Wind Strike",
    {3, :mystic} => "Wind Strike",
    {1, :mystic} => "Chill Flame"
  }

  @monster_spells %{
    "NPC Windstrike - Magic 1" => %{
      kind: :magic,
      power: 18,
      mp: 7,
      reuse: 3_000,
      cast: 4_000,
      range: 600
    },
    "NPC HP Drain - Magic 1" => %{
      kind: :drain,
      power: 18,
      mp: 9,
      reuse: 3_000,
      cast: 4_000,
      range: 600
    },
    "NPC HP Drain - Magic 2" => %{
      kind: :drain,
      power: 26,
      mp: 14,
      reuse: 3_000,
      cast: 4_000,
      range: 600
    },
    "NPC Aura Burn - Magic 1" => %{
      kind: :magic,
      power: 5,
      mp: 3,
      reuse: 1_000,
      cast: 1_500,
      range: 150
    },
    "NPC Aura Burn - Magic 2" => %{
      kind: :magic,
      power: 7,
      mp: 3,
      reuse: 1_000,
      cast: 1_500,
      range: 150
    },
    "NPC Windstrike - Slow 1" => %{
      kind: :magic,
      power: 5,
      mp: 13,
      reuse: 8_000,
      cast: 2_000,
      range: 1_000
    },
    "NPC Windstrike - Slow 2" => %{
      kind: :magic,
      power: 8,
      mp: 20,
      reuse: 8_000,
      cast: 2_000,
      range: 1_000
    },
    "NPC HP Drain - Slow 1" => %{
      kind: :drain,
      power: 5,
      mp: 17,
      reuse: 8_000,
      cast: 2_000,
      range: 1_000
    },
    "NPC Prominence - Slow 1" => %{
      kind: :magic,
      power: 5,
      mp: 13,
      reuse: 8_000,
      cast: 2_000,
      range: 1_000
    }
  }

  # Rules §20: how far a character's blow, bow shot and spell reach on the fight's line.
  @reach %{blow: 40, bow: 500, spell: 600, notice: 500}

  # The only kinds, slots and shops an item may name; listed so the data file mints no atom.
  @item_words ~w(weapon shield armour jewellery chest legs necklace village orc-village starting light
                 magic)a

  # Rules §23 and §24: every item, a table in the hundreds and so a data file.
  @external_resource items_path = Path.join(:code.priv_dir(:mini_lineage), "game/items.csv")
  @items (
           [header | rows] = items_path |> File.read!() |> String.split("\n", trim: true)

           keys =
             ~w(name kind slot hands type p_atk m_atk atk_spd critical accuracy spread p_def m_def
                shield_def shield_rate mp price sold)a

           ^header = Enum.join(keys, ",")
           words = ~w(name kind slot type sold)a

           # A blank cell is a stat the item does not have, read as nil.
           for row <- rows, into: %{} do
             item =
               keys
               |> Enum.zip(String.split(row, ","))
               |> Map.new(fn
                 {k, ""} -> {k, nil}
                 {k, v} -> {k, if(k in words, do: v, else: String.to_integer(v))}
               end)

             item = %{
               item
               | kind: String.to_existing_atom(item.kind),
                 slot: String.to_existing_atom(item.slot),
                 sold: String.to_existing_atom(item.sold)
             }

             {item.name, item}
           end
         )

  # Rules §26: the potions, each healing its whole amount at once. Every gear stat is there and
  # empty, so nothing reading an item has to ask which it holds.
  @potions (
             blank =
               Map.new(
                 ~w(hands type p_atk m_atk atk_spd critical accuracy spread p_def m_def shield_def
                    shield_rate mp)a,
                 &{&1, nil}
               )

             for {name, heals, price, sold} <- [{"Lesser Healing Potion", 112, 90, :village}],
                 into: %{},
                 do:
                   {name,
                    Map.merge(blank, %{
                      name: name,
                      kind: :potion,
                      slot: :potion,
                      heals: heals,
                      price: price,
                      sold: sold
                    })}
           )

  # Rules §23: each set's kit, {equipped, carried}.
  @kits %{
    {0, :fighter} =>
      {["Squire's Sword", "Squire's Shirt", "Squire's Pants"],
       ["Squire's Dagger", "Squire's Bow"]},
    {2, :fighter} => {["Squire's Bow", "Squire's Shirt", "Squire's Pants"], []},
    {3, :fighter} => {["Squire's Dagger", "Squire's Shirt", "Squire's Pants"], []},
    {1, :fighter} =>
      {["Training Gloves", "Squire's Shirt", "Squire's Pants"], ["Squire's Sword"]},
    {0, :mystic} => {["Apprentice's Wand", "Apprentice's Tunic", "Apprentice's Stockings"], []},
    {2, :mystic} => {["Apprentice's Wand", "Apprentice's Tunic", "Apprentice's Stockings"], []},
    {3, :mystic} => {["Apprentice's Wand", "Apprentice's Tunic", "Apprentice's Stockings"], []},
    {1, :mystic} => {["Training Gloves", "Apprentice's Tunic", "Apprentice's Stockings"], []}
  }

  # Rules §23: the weapon each weapon skill needs, in either hand; a spell needs none.
  @skill_weapons %{
    "Power Strike" => ["sword"],
    "Power Shot" => ["bow"],
    "Mortal Blow" => ["dagger"],
    "Iron Punch" => ["fists"]
  }

  @capacity 80

  # Rules §25: what each set's trainer teaches, at what level and for how much SP.
  @external_resource trainer_path = Path.join(:code.priv_dir(:mini_lineage), "game/trainer.csv")
  @trainer (
             [header | rows] = trainer_path |> File.read!() |> String.split("\n", trim: true)
             ^header = "set,skill,level,learn_at,sp"

             for row <- rows do
               [set, skill, level, learn_at, sp] = String.split(row, ",")

               %{
                 set: set,
                 skill: skill,
                 level: String.to_integer(level),
                 learn_at: String.to_integer(learn_at),
                 sp: String.to_integer(sp)
               }
             end
           )

  # Rules §22: what the server multiplies a kill's pay by.
  @rates %{exp: 5, sp: 5, adena: 20}

  def sets, do: @sets
  def towns, do: @towns

  def town(slug),
    do: Enum.find(@towns, &(&1.slug == slug)) || raise(ArgumentError, "no town #{inspect(slug)}")

  def town?(slug), do: Enum.any?(@towns, &(&1.slug == slug))
  def hometown(race_id), do: Map.fetch!(@hometowns, race_id)

  @doc "Whether a town is one of the four starting villages, which have the shops of §24."
  def village?(slug), do: slug in Map.values(@hometowns)

  @doc "Every route out of a town, as `%{to, fee}`, in the order its Gatekeeper lists them."
  def routes_from(slug) do
    for {a, b, fee} <- @routes, slug in [a, b], do: %{to: if(a == slug, do: b, else: a), fee: fee}
  end

  def route(from, to), do: Enum.find(routes_from(from), &(&1.to == to))

  def modifiers(condition), do: Map.fetch!(@modifiers, condition)

  def set(race_id, path), do: Enum.find(@sets, &(&1.race_id == race_id and &1.path == path))
  def path(path), do: Map.fetch!(@paths, path)
  def bonus_curve(attr), do: Map.fetch!(@bonus, attr)
  def experience(level), do: Enum.at(@experience, level - 1)
  def max_level, do: length(@experience)

  def grounds, do: @grounds
  def ground(slug), do: Enum.find(@grounds, &(&1.slug == slug))
  def ground_of(town), do: Enum.find(@grounds, &(&1.town == town))

  @doc "A ground's monsters, in the order §17 lists them, as §18 gives them."
  def monsters_of(ground), do: Enum.map(ground.monsters, &monster(String.replace(&1, "_", " ")))

  def monster(name), do: Map.fetch!(@monsters, name)
  def monsters, do: @monsters

  def skill(name), do: @skills |> Map.fetch!(name) |> Map.put(:name, name)
  def skills, do: @skills
  def first_skill(race_id, path), do: skill(Map.fetch!(@first_skills, {race_id, path}))

  def monster_spell(name), do: @monster_spells |> Map.fetch!(name) |> Map.put(:name, name)
  def monster_spells, do: @monster_spells

  @doc """
  Rules §20: how far a blow (and a physical skill), a bow's shot or a character's spell reaches, and
  how far off an aggressive monster notices a character.
  """
  def reach(kind), do: Map.fetch!(@reach, kind)
  def rate(kind), do: Map.fetch!(@rates, kind)

  def item_words, do: @item_words
  def part(slot), do: Map.fetch!(@parts, slot)
  def parts, do: @parts

  @doc """
  Rules §7: what an equipped piece counts for, its canon defence × its part's share ÷ its slot's own,
  by its own kind of armour.
  """
  def counts_for(item) do
    part = part(item.slot)

    case item.slot do
      :necklace -> item.m_def * part.mind / part.jewel
      _ -> item.p_def * part[path_of(item.type)] / part[String.to_existing_atom(item.type)]
    end
  end

  defp path_of("magic"), do: :mystic
  defp path_of(_light), do: :fighter

  def item(name), do: Map.get(@items, name) || Map.fetch!(@potions, name)
  def item?(name), do: Map.has_key?(@items, name) or Map.has_key?(@potions, name)
  @doc "Rules §24's gear; the potions are §26's."
  def items, do: @items
  def potions, do: @potions

  @doc "Rules §26: a potion stacks, one place in the inventory however many it holds."
  def stacks?(item), do: item.kind == :potion
  def kit(race_id, path), do: Map.fetch!(@kits, {race_id, path})
  def capacity, do: @capacity

  def weapon_skill?(skill), do: Map.has_key?(@skill_weapons, skill)

  @doc "Rules §23: the weapon types a skill can be used with, or none for one that needs none."
  def skill_weapons(skill), do: Map.get(@skill_weapons, skill, [])

  @doc "Rules §23: whether a skill can be used with what is in hand (nil, bare-handed)."
  def skill_weapon?(skill, weapon) do
    case Map.fetch(@skill_weapons, skill) do
      :error -> true
      {:ok, types} -> weapon != nil and weapon.type in types
    end
  end

  @doc "Rules §24: what a village's traders sell, in the order the table lists them."
  def stock(town) do
    sold = if town == "orc-village", do: [:village, :"orc-village"], else: [:village]

    (Map.values(@items) ++ Map.values(@potions))
    |> Enum.filter(&(&1.sold in sold))
    |> Enum.sort_by(&{kind_order(&1.kind), slot_order(&1.slot), &1.type || "", &1.price, &1.name})
  end

  defp kind_order(kind),
    do: Enum.find_index([:weapon, :shield, :armour, :jewellery, :potion], &(&1 == kind))

  defp slot_order(slot),
    do:
      Enum.find_index(
        ~w(weapon shield chest legs necklace potion)a,
        &(&1 == slot)
      )

  @doc "Rules §25: every line a set's trainer teaches, in the order the table lists them."
  def lessons(set_name), do: Enum.filter(@trainer, &(&1.set == set_name))

  def skill_known?(name),
    do: Map.has_key?(@skills, name) or Enum.any?(@trainer, &(&1.skill == name))

  @doc "Rules §25: a skill at the level a character knows it."
  def skill(name, level) do
    case @skill_levels |> Map.fetch!(name) |> Enum.at(level - 1) do
      {power, mp} -> %{skill(name) | power: power, mp: mp}
      %{} = changes -> Map.merge(skill(name), changes)
    end
  end

  def skill_levels(name), do: Map.fetch!(@skill_levels, name)
end
