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
    1,
    2,
    4,
    10,
    21,
    38,
    65,
    105,
    161,
    238,
    339,
    471,
    639,
    848,
    1107,
    1421,
    1800,
    2252,
    2787,
    3413,
    4142,
    4986,
    5955,
    7063,
    8324,
    9751,
    11360,
    13166,
    15186,
    17438,
    19939,
    22709,
    25767,
    29135,
    32834,
    36887,
    41318,
    46150,
    51410,
    57124,
    63319,
    70024,
    77269,
    85083,
    93499,
    102_549,
    112_267,
    122_688,
    133_847,
    151_750,
    170_875,
    191_279,
    213_026,
    236_176,
    269_002,
    303_874,
    340_885,
    380_127,
    421_697,
    487_691,
    557_478,
    631_213,
    709_056,
    791_172,
    906_579,
    1_028_138,
    1_156_085,
    1_290_659,
    1_432_109,
    1_580_686,
    1_775_641,
    2_021_064,
    2_321_257,
    2_680_734,
    3_104_253,
    3_837_587,
    5_037_587,
    6_997_587,
    14_000_000
  ]

  def sets, do: @sets
  def town(race_id), do: Map.fetch!(@towns, race_id)
  def set(race_id, path), do: Enum.find(@sets, &(&1.race_id == race_id and &1.path == path))
  def path(path), do: Map.fetch!(@paths, path)
  def paths, do: @paths
  def bonus_curve(attr), do: Map.fetch!(@bonus, attr)
  def bonus_curves, do: @bonus
  def experience(level), do: Enum.at(@experience, level - 1)
  def max_level, do: length(@experience)
end
