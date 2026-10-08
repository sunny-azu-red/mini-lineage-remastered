defmodule MiniLineage.Game.Classes do
  @moduledoc """
  Every class of the four races, as L2J Mobius CT_0 Interlude defines it (`docs/lineage2-canon.md`).
  A transferred class keeps its starting class's attributes and combat base, and its HP/MP table
  matches its parent's up to the transfer, so each class stores only its own segment: the first
  level's gain and how much that gain grows per level. `class_tables_test.exs` holds every row to
  the datapack.
  """

  # Starting classes carry `{level 1 value, gain, growth}`; a transfer carries `{gain, growth}` from
  # the level after its own.
  @classes [
    %{
      id: 0,
      name: "Human Fighter",
      race_id: 0,
      archetype: :fighter,
      parent_id: nil,
      level: 1,
      attributes: %{str: 40, con: 43, dex: 30, int: 21, wit: 11, men: 25},
      hp: {80.0, 11.83, 0.13},
      mp: {30.0, 5.46, 0.06}
    },
    %{
      id: 1,
      name: "Warrior",
      race_id: 0,
      archetype: :fighter,
      parent_id: 0,
      level: 20,
      hp: {33.0, 0.3},
      mp: {9.9, 0.09}
    },
    %{
      id: 2,
      name: "Gladiator",
      race_id: 0,
      archetype: :fighter,
      parent_id: 1,
      level: 40,
      hp: {49.4, 0.38},
      mp: {19.5, 0.15}
    },
    %{
      id: 3,
      name: "Warlord",
      race_id: 0,
      archetype: :fighter,
      parent_id: 1,
      level: 40,
      hp: {54.6, 0.42},
      mp: {19.5, 0.15}
    },
    %{
      id: 4,
      name: "Human Knight",
      race_id: 0,
      archetype: :fighter,
      parent_id: 0,
      level: 20,
      hp: {29.7, 0.27},
      mp: {9.9, 0.09}
    },
    %{
      id: 5,
      name: "Paladin",
      race_id: 0,
      archetype: :fighter,
      parent_id: 4,
      level: 40,
      hp: {46.8, 0.36},
      mp: {19.5, 0.15}
    },
    %{
      id: 6,
      name: "Dark Avenger",
      race_id: 0,
      archetype: :fighter,
      parent_id: 4,
      level: 40,
      hp: {46.8, 0.36},
      mp: {19.5, 0.15}
    },
    %{
      id: 7,
      name: "Rogue",
      race_id: 0,
      archetype: :fighter,
      parent_id: 0,
      level: 20,
      hp: {27.5, 0.25},
      mp: {9.9, 0.09}
    },
    %{
      id: 8,
      name: "Treasure Hunter",
      race_id: 0,
      archetype: :fighter,
      parent_id: 7,
      level: 40,
      hp: {41.6, 0.32},
      mp: {19.5, 0.15}
    },
    %{
      id: 9,
      name: "Hawkeye",
      race_id: 0,
      archetype: :fighter,
      parent_id: 7,
      level: 40,
      hp: {44.2, 0.34},
      mp: {19.5, 0.15}
    },
    %{
      id: 10,
      name: "Human Mystic",
      race_id: 0,
      archetype: :mystic,
      parent_id: nil,
      level: 1,
      attributes: %{str: 22, con: 27, dex: 21, int: 41, wit: 20, men: 39},
      hp: {101.0, 15.47, 0.17},
      mp: {40.0, 7.28, 0.08}
    },
    %{
      id: 11,
      name: "Human Wizard",
      race_id: 0,
      archetype: :mystic,
      parent_id: 10,
      level: 20,
      hp: {27.5, 0.25},
      mp: {13.2, 0.12}
    },
    %{
      id: 12,
      name: "Sorcerer",
      race_id: 0,
      archetype: :mystic,
      parent_id: 11,
      level: 40,
      hp: {45.5, 0.35},
      mp: {26.0, 0.2}
    },
    %{
      id: 13,
      name: "Necromancer",
      race_id: 0,
      archetype: :mystic,
      parent_id: 11,
      level: 40,
      hp: {45.5, 0.35},
      mp: {26.0, 0.2}
    },
    %{
      id: 14,
      name: "Warlock",
      race_id: 0,
      archetype: :mystic,
      parent_id: 11,
      level: 40,
      hp: {49.4, 0.38},
      mp: {26.0, 0.2}
    },
    %{
      id: 15,
      name: "Cleric",
      race_id: 0,
      archetype: :mystic,
      parent_id: 10,
      level: 20,
      hp: {34.1, 0.31},
      mp: {13.2, 0.12}
    },
    %{
      id: 16,
      name: "Bishop",
      race_id: 0,
      archetype: :mystic,
      parent_id: 15,
      level: 40,
      hp: {49.4, 0.38},
      mp: {26.0, 0.2}
    },
    %{
      id: 17,
      name: "Prophet",
      race_id: 0,
      archetype: :mystic,
      parent_id: 15,
      level: 40,
      hp: {53.3, 0.41},
      mp: {26.0, 0.2}
    },
    %{
      id: 18,
      name: "Elven Fighter",
      race_id: 2,
      archetype: :fighter,
      parent_id: nil,
      level: 1,
      attributes: %{str: 36, con: 36, dex: 35, int: 23, wit: 14, men: 26},
      hp: {89.0, 12.74, 0.14},
      mp: {30.0, 5.46, 0.06}
    },
    %{
      id: 19,
      name: "Elven Knight",
      race_id: 2,
      archetype: :fighter,
      parent_id: 18,
      level: 20,
      hp: {33.0, 0.3},
      mp: {9.9, 0.09}
    },
    %{
      id: 20,
      name: "Temple Knight",
      race_id: 2,
      archetype: :fighter,
      parent_id: 19,
      level: 40,
      hp: {52.0, 0.4},
      mp: {19.5, 0.15}
    },
    %{
      id: 21,
      name: "Swordsinger",
      race_id: 2,
      archetype: :fighter,
      parent_id: 19,
      level: 40,
      hp: {54.6, 0.42},
      mp: {19.5, 0.15}
    },
    %{
      id: 22,
      name: "Elven Scout",
      race_id: 2,
      archetype: :fighter,
      parent_id: 18,
      level: 20,
      hp: {30.8, 0.28},
      mp: {9.9, 0.09}
    },
    %{
      id: 23,
      name: "Plains Walker",
      race_id: 2,
      archetype: :fighter,
      parent_id: 22,
      level: 40,
      hp: {46.8, 0.36},
      mp: {19.5, 0.15}
    },
    %{
      id: 24,
      name: "Silver Ranger",
      race_id: 2,
      archetype: :fighter,
      parent_id: 22,
      level: 40,
      hp: {49.4, 0.38},
      mp: {19.5, 0.15}
    },
    %{
      id: 25,
      name: "Elven Mystic",
      race_id: 2,
      archetype: :mystic,
      parent_id: nil,
      level: 1,
      attributes: %{str: 21, con: 25, dex: 24, int: 37, wit: 23, men: 40},
      hp: {104.0, 15.47, 0.17},
      mp: {40.0, 7.28, 0.08}
    },
    %{
      id: 26,
      name: "Elven Wizard",
      race_id: 2,
      archetype: :mystic,
      parent_id: 25,
      level: 20,
      hp: {28.6, 0.26},
      mp: {13.2, 0.12}
    },
    %{
      id: 27,
      name: "Spellsinger",
      race_id: 2,
      archetype: :mystic,
      parent_id: 26,
      level: 40,
      hp: {48.1, 0.37},
      mp: {26.0, 0.2}
    },
    %{
      id: 28,
      name: "Elemental Summoner",
      race_id: 2,
      archetype: :mystic,
      parent_id: 26,
      level: 40,
      hp: {50.7, 0.39},
      mp: {26.0, 0.2}
    },
    %{
      id: 29,
      name: "Elven Oracle",
      race_id: 2,
      archetype: :mystic,
      parent_id: 25,
      level: 20,
      hp: {35.2, 0.32},
      mp: {13.2, 0.12}
    },
    %{
      id: 30,
      name: "Elven Elder",
      race_id: 2,
      archetype: :mystic,
      parent_id: 29,
      level: 40,
      hp: {54.6, 0.42},
      mp: {26.0, 0.2}
    },
    %{
      id: 31,
      name: "Dark Fighter",
      race_id: 3,
      archetype: :fighter,
      parent_id: nil,
      level: 1,
      attributes: %{str: 41, con: 32, dex: 34, int: 25, wit: 12, men: 26},
      hp: {94.0, 13.65, 0.15},
      mp: {30.0, 5.46, 0.06}
    },
    %{
      id: 32,
      name: "Palus Knight",
      race_id: 3,
      archetype: :fighter,
      parent_id: 31,
      level: 20,
      hp: {35.2, 0.32},
      mp: {9.9, 0.09}
    },
    %{
      id: 33,
      name: "Shillien Knight",
      race_id: 3,
      archetype: :fighter,
      parent_id: 32,
      level: 40,
      hp: {54.6, 0.42},
      mp: {19.5, 0.15}
    },
    %{
      id: 34,
      name: "Bladedancer",
      race_id: 3,
      archetype: :fighter,
      parent_id: 32,
      level: 40,
      hp: {58.5, 0.45},
      mp: {19.5, 0.15}
    },
    %{
      id: 35,
      name: "Assassin",
      race_id: 3,
      archetype: :fighter,
      parent_id: 31,
      level: 20,
      hp: {33.0, 0.3},
      mp: {9.9, 0.09}
    },
    %{
      id: 36,
      name: "Abyss Walker",
      race_id: 3,
      archetype: :fighter,
      parent_id: 35,
      level: 40,
      hp: {49.4, 0.38},
      mp: {19.5, 0.15}
    },
    %{
      id: 37,
      name: "Phantom Ranger",
      race_id: 3,
      archetype: :fighter,
      parent_id: 35,
      level: 40,
      hp: {52.0, 0.4},
      mp: {19.5, 0.15}
    },
    %{
      id: 38,
      name: "Dark Mystic",
      race_id: 3,
      archetype: :mystic,
      parent_id: nil,
      level: 1,
      attributes: %{str: 23, con: 24, dex: 23, int: 44, wit: 19, men: 37},
      hp: {106.0, 15.47, 0.17},
      mp: {40.0, 7.28, 0.08}
    },
    %{
      id: 39,
      name: "Dark Wizard",
      race_id: 3,
      archetype: :mystic,
      parent_id: 38,
      level: 20,
      hp: {29.7, 0.27},
      mp: {13.2, 0.12}
    },
    %{
      id: 40,
      name: "Spellhowler",
      race_id: 3,
      archetype: :mystic,
      parent_id: 39,
      level: 40,
      hp: {48.1, 0.37},
      mp: {26.0, 0.2}
    },
    %{
      id: 41,
      name: "Phantom Summoner",
      race_id: 3,
      archetype: :mystic,
      parent_id: 39,
      level: 40,
      hp: {52.0, 0.4},
      mp: {26.0, 0.2}
    },
    %{
      id: 42,
      name: "Shillien Oracle",
      race_id: 3,
      archetype: :mystic,
      parent_id: 38,
      level: 20,
      hp: {36.3, 0.33},
      mp: {13.2, 0.12}
    },
    %{
      id: 43,
      name: "Shillien Elder",
      race_id: 3,
      archetype: :mystic,
      parent_id: 42,
      level: 40,
      hp: {54.6, 0.42},
      mp: {26.0, 0.2}
    },
    %{
      id: 44,
      name: "Orc Fighter",
      race_id: 1,
      archetype: :fighter,
      parent_id: nil,
      level: 1,
      attributes: %{str: 40, con: 47, dex: 26, int: 18, wit: 12, men: 27},
      hp: {80.0, 12.74, 0.14},
      mp: {30.0, 5.46, 0.06}
    },
    %{
      id: 45,
      name: "Orc Raider",
      race_id: 1,
      archetype: :fighter,
      parent_id: 44,
      level: 20,
      hp: {35.2, 0.32},
      mp: {9.9, 0.09}
    },
    %{
      id: 46,
      name: "Destroyer",
      race_id: 1,
      archetype: :fighter,
      parent_id: 45,
      level: 40,
      hp: {57.2, 0.44},
      mp: {19.5, 0.15}
    },
    %{
      id: 47,
      name: "Monk",
      race_id: 1,
      archetype: :fighter,
      parent_id: 44,
      level: 20,
      hp: {33.0, 0.3},
      mp: {9.9, 0.09}
    },
    %{
      id: 48,
      name: "Tyrant",
      race_id: 1,
      archetype: :fighter,
      parent_id: 47,
      level: 40,
      hp: {54.6, 0.42},
      mp: {19.5, 0.15}
    },
    %{
      id: 49,
      name: "Orc Mystic",
      race_id: 1,
      archetype: :mystic,
      parent_id: nil,
      level: 1,
      attributes: %{str: 27, con: 31, dex: 24, int: 31, wit: 15, men: 42},
      hp: {95.0, 15.47, 0.17},
      mp: {40.0, 7.28, 0.08}
    },
    %{
      id: 50,
      name: "Orc Shaman",
      race_id: 1,
      archetype: :mystic,
      parent_id: 49,
      level: 20,
      hp: {35.2, 0.32},
      mp: {13.2, 0.12}
    },
    %{
      id: 51,
      name: "Overlord",
      race_id: 1,
      archetype: :mystic,
      parent_id: 50,
      level: 40,
      hp: {53.3, 0.41},
      mp: {26.0, 0.2}
    },
    %{
      id: 52,
      name: "Warcryer",
      race_id: 1,
      archetype: :mystic,
      parent_id: 50,
      level: 40,
      hp: {53.3, 0.41},
      mp: {26.0, 0.2}
    }
  ]

  # Naked bases by archetype: P.Def and M.Def are the sums of the empty slots an item would replace.
  # Magic crit starts at 1, not the template's unread 5: `getMCriticalHit` passes 1 into the chain.
  @bases %{
    fighter: %{
      p_atk: 4,
      m_atk: 6,
      p_def: 80,
      m_def: 41,
      crit: 4,
      m_crit: 1,
      p_atk_spd: 300,
      m_atk_spd: 333
    },
    mystic: %{
      p_atk: 3,
      m_atk: 6,
      p_def: 54,
      m_def: 41,
      crit: 4,
      m_crit: 1,
      p_atk_spd: 300,
      m_atk_spd: 333
    }
  }

  # Total experience to reach each level, 1 to 80, before `Constants` divides it.
  @experience [
    0,
    68,
    363,
    1_168,
    2_884,
    6_038,
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

  @by_id Map.new(@classes, &{&1.id, &1})
  @segment_start %{1 => 2, 20 => 21, 40 => 41}

  def all, do: @classes
  def get(id), do: Map.fetch!(@by_id, id)
  def fetch(id), do: Map.fetch(@by_id, id)

  @doc "The class a race starts as, for `:fighter` or `:mystic`."
  def starting(race_id, archetype),
    do:
      Enum.find(
        @classes,
        &(&1.race_id == race_id and &1.parent_id == nil and &1.archetype == archetype)
      )

  def children(id), do: Enum.filter(@classes, &(&1.parent_id == id))

  @doc "From the starting class down to `id`."
  def lineage(id), do: climb(get(id), [])

  defp climb(%{parent_id: nil} = class, acc), do: [class | acc]
  defp climb(class, acc), do: climb(get(class.parent_id), [class | acc])

  def root(id), do: hd(lineage(id))

  def attributes(id), do: root(id).attributes
  def bases(id), do: Map.fetch!(@bases, get(id).archetype)

  def hp(id, level), do: table(lineage(id), :hp, level)
  def mp(id, level), do: table(lineage(id), :mp, level)

  # Each class in the lineage owns the levels from its segment's start to the next class's.
  defp table([root | _] = lineage, key, level) do
    {first, _gain, _growth} = Map.fetch!(root, key)
    ends = Enum.map(tl(lineage), &(@segment_start[&1.level] - 1)) ++ [level]

    lineage
    |> Enum.zip(ends)
    |> Enum.reduce(first, fn {class, last}, value ->
      from = @segment_start[class.level]
      count = max(0, min(last, level) - from + 1)
      {gain, growth} = segment(Map.fetch!(class, key))

      value + count * gain + growth * count * (count - 1) / 2
    end)
  end

  defp segment({_first, gain, growth}), do: {gain, growth}
  defp segment(pair), do: pair

  @doc "HP regenerated per 3 s tick before CON and the level modifier; the same for every class."
  def hp_regen(level) when level <= 10, do: 2.0 + 0.05 * (level - 1)
  def hp_regen(level), do: 2.5 + 0.1 * (level - 11)

  def mp_regen(level), do: 0.9 + 0.3 * div(level - 1, 10)

  def experience(level), do: Enum.at(@experience, level - 1)
  def max_level, do: length(@experience)
end
