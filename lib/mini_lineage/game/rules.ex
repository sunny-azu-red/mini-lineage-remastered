defmodule MiniLineage.Game.Rules do
  @moduledoc """
  The base layer's tables, exactly as `docs/rules.md` writes them: the eight starting sets, what
  each path starts with, the attribute bonus curves and the EXP each level needs. `rules_test.exs`
  reads the tables back out of the document, so the two cannot disagree.
  """

  # Rules §3 and §6: each set's attributes, and its HP and MP as {start, gain, growth}.
  @sets [
    %{
      race_id: 0,
      path: :fighter,
      name: "Human Fighter",
      attributes: %{str: 40, con: 43, dex: 30, int: 21, wit: 11, men: 25},
      hp: {80.0, 11.83, 0.13},
      mp: {30.0, 5.46, 0.06}
    },
    %{
      race_id: 0,
      path: :mystic,
      name: "Human Mystic",
      attributes: %{str: 22, con: 27, dex: 21, int: 41, wit: 20, men: 39},
      hp: {101.0, 15.47, 0.17},
      mp: {40.0, 7.28, 0.08}
    },
    %{
      race_id: 2,
      path: :fighter,
      name: "Elven Fighter",
      attributes: %{str: 36, con: 36, dex: 35, int: 23, wit: 14, men: 26},
      hp: {89.0, 12.74, 0.14},
      mp: {30.0, 5.46, 0.06}
    },
    %{
      race_id: 2,
      path: :mystic,
      name: "Elven Mystic",
      attributes: %{str: 21, con: 25, dex: 24, int: 37, wit: 23, men: 40},
      hp: {104.0, 15.47, 0.17},
      mp: {40.0, 7.28, 0.08}
    },
    %{
      race_id: 3,
      path: :fighter,
      name: "Dark Fighter",
      attributes: %{str: 41, con: 32, dex: 34, int: 25, wit: 12, men: 26},
      hp: {94.0, 13.65, 0.15},
      mp: {30.0, 5.46, 0.06}
    },
    %{
      race_id: 3,
      path: :mystic,
      name: "Dark Mystic",
      attributes: %{str: 23, con: 24, dex: 23, int: 44, wit: 19, men: 37},
      hp: {106.0, 15.47, 0.17},
      mp: {40.0, 7.28, 0.08}
    },
    %{
      race_id: 1,
      path: :fighter,
      name: "Orc Fighter",
      attributes: %{str: 40, con: 47, dex: 26, int: 18, wit: 12, men: 27},
      hp: {80.0, 12.74, 0.14},
      mp: {30.0, 5.46, 0.06}
    },
    %{
      race_id: 1,
      path: :mystic,
      name: "Orc Mystic",
      attributes: %{str: 27, con: 31, dex: 24, int: 31, wit: 15, men: 42},
      hp: {95.0, 15.47, 0.17},
      mp: {40.0, 7.28, 0.08}
    }
  ]

  # Rules §1: where each race starts, and stays until there is somewhere else to go.
  @towns %{
    0 => %{name: "Talking Island Village", emoji: "🏝️"},
    1 => %{name: "Orc Village", emoji: "🏕️"},
    2 => %{name: "Elven Village", emoji: "🌳"},
    3 => %{name: "Dark Elven Village", emoji: "🌑"}
  }

  # Rules §7: what a path starts with before anything is added to it.
  @paths %{
    fighter: %{power: 4, magic: 6, body: 80, mind: 41},
    mystic: %{power: 3, magic: 6, body: 54, mind: 41}
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

  def sets, do: @sets
  def town(race_id), do: Map.fetch!(@towns, race_id)
  def set(race_id, path), do: Enum.find(@sets, &(&1.race_id == race_id and &1.path == path))
  def path(path), do: Map.fetch!(@paths, path)
  def bonus_curve(attr), do: Map.fetch!(@bonus, attr)
  def experience(level), do: Enum.at(@experience, level - 1)
  def max_level, do: length(@experience)
end
