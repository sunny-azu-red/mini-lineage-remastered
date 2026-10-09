defmodule MiniLineage.Game.Classes do
  @moduledoc """
  The class tree of the four races. A starting class is one of the base layer's eight sets
  (`docs/rules.md`, held by `Rules`); a transfer keeps its attributes and continues its HP and MP from
  where the run stands, so it stores only its own segment: the first level's gain and how much that
  gain grows per level.
  """
  alias MiniLineage.Game.Rules

  # A transfer carries `{gain, growth}` from the level after its own; a starting class's
  # `{start, gain, growth}` comes from `Rules`.
  @classes [
    %{
      id: 0,
      name: "Human Fighter",
      race_id: 0,
      archetype: :fighter,
      parent_id: nil,
      level: 1
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
      level: 1
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
      level: 1
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
      level: 1
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
      level: 1
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
      level: 1
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
      level: 1
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
      level: 1
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

  # A starting class is one of the base layer's eight sets; only the transfers are this module's.
  @classes Enum.map(@classes, fn
             %{parent_id: nil} = class ->
               Map.merge(
                 class,
                 Map.take(Rules.set(class.race_id, class.archetype), [:attributes, :hp, :mp])
               )

             class ->
               class
           end)

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
  def path(id), do: Rules.path(get(id).archetype)

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
end
