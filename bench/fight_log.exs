# Every way the fight log can read, gathered from fights the game itself plays: each set at levels
# 1 to 20 (past its ground at 15), in its starting kit and in the best its village sells (the `twink` key's), at full, low
# and empty MP and full and low HP (once with no heal before the pull and no potion, so it heals in
# the fight), against every monster its ground draws at that level. Each clause is reduced to its
# shape (a monster as M, a skill or spell as S, an item as I, each with its emoji, a number as N)
# and listed with how often it came and one real line it came in, then the longest rounds and one
# whole fight a set. Read it after any change to how the log is told, to see every sentence it makes.
#
#   MIX_ENV=test mix run --no-start bench/fight_log.exs [--fights N] [--only "Set name,Set name"]
#
# Seeded, so two builds tell the same fights and their catalogs compare line for line.
alias MiniLineage.Game.{
  Actions,
  Clock,
  Constants,
  Hunt,
  Math,
  Names,
  Narrative,
  Player,
  Rng,
  Rules
}

Application.ensure_all_started(:tz)

{opts, _args} = OptionParser.parse!(System.argv(), strict: [fights: :integer, only: :string])
fights = Keyword.get(opts, :fights, 3)
only = opts[:only] && String.split(opts[:only], ",")

:rand.seed(:exsss, {20, 26, 10})
Rng.put_source(fn -> :rand.uniform() end)
Clock.put_now(~U[2026-07-01 09:00:00Z])

# Every lesson its trainer has taught by the level, each at the highest it has reached.
trained = fn player, level ->
  set = Rules.set(player.race_id, player.path)

  skills =
    for lesson <- Rules.lessons(set.name),
        lesson.learn_at <= level,
        reduce: player.skills,
        do: (known -> Map.update(known, lesson.skill, lesson.level, &max(&1, lesson.level)))

  Player.restore_fully(%{player | experience: Math.xp_for_level(level), skills: skills})
end

kit = fn race_id, path ->
  {player, _flash} = Player.initialize(%Player{}, Constants.race(race_id), path, "Hunter")
  %{player | items: player.items ++ [Player.new_item("Lesser Healing Potion", false, 10)]}
end

plain = fn html ->
  html |> Narrative.alert() |> String.replace(~r/<[^>]+>/, "") |> String.replace("&bull;", "•")
end

geared = fn race_id, path ->
  {player, _flash} = Actions.dev_twink(kit.(race_id, path))
  %{player | skills: kit.(race_id, path).skills}
end

played =
  for race_id <- 0..3,
      path <- [:fighter, :mystic],
      set = Rules.set(race_id, path),
      only == nil or set.name in only,
      {gear, dressed} <- [kit: kit, best: geared],
      level <- [1, 3, 5, 7, 10, 13, 16, 20],
      ground = Rules.ground_of(Rules.hometown(race_id)),
      ladder = Rules.monsters_of(ground),
      drawn = Enum.filter(ladder, &(&1.level in (level - 1)..(level + 1))),
      monster <- if(drawn == [], do: [Enum.min_by(ladder, &abs(&1.level - level))], else: drawn),
      {mp, hp, pull, potion} <- [
        {1.0, 1.0, 70, 50},
        {0.3, 1.0, 70, 50},
        {0.0, 1.0, 70, 50},
        {1.0, 0.4, 70, 50},
        {1.0, 0.3, 0, 0}
      ],
      _fight <- 1..fights do
    whole = trained.(dressed.(race_id, path), level)
    player = %{whole | mp: trunc(whole.mp * mp), health: max(trunc(whole.health * hp), 1)}
    stats = Player.stats(player)
    foe = Hunt.foe(monster)

    bars = %{
      health: player.health,
      mp: player.mp,
      potions: Player.potions(player),
      potion_at: potion,
      heal_pull_at: pull,
      path: player.path,
      heal_fight_at: 50
    }

    result = Hunt.fight(stats, bars, Player.fighting_skills(player), foe)

    you = %{
      level: level,
      max_hp: stats.max_hp,
      hp: player.health,
      weapon: stats.weapon,
      shield: stats.shield
    }

    entries =
      for entry <- Narrative.build_fight_log(foe, ground, result.log, you, result.before),
          do: {plain.(entry.head), plain.(entry.line)}

    # Each skill and item as the log names it, emoji and all, to fold into S and I.
    named =
      for {_round, event} <- result.log ++ Enum.map(elem(result.before, 0), &{0, &1}),
          is_tuple(event),
          name <- Tuple.to_list(event),
          is_binary(name) do
        cond do
          elem(event, 0) in [:foe_begin, :foe_cast, :foe_drain] ->
            shown = Rules.monster_spell(name).shown
            {"#{Names.skill_emoji(shown)} #{shown}", "S"}

          elem(event, 0) == :potion ->
            {"#{Names.item_emoji(name)} #{name}", "I"}

          true ->
            {"#{Names.skill_emoji(name)} #{name}", "S"}
        end
      end

    held =
      for item <- [stats.weapon, stats.shield],
          item,
          do: {"#{Names.item_emoji(item)} #{item.name}", "I"}

    %{
      set: set.name,
      gear: gear,
      level: level,
      monster: foe.name,
      entries: entries,
      names: named ++ held
    }
  end

# Longest first, so "Healing Potion" never eats the end of "Lesser Healing Potion".
longest_first = &Enum.sort_by(Enum.uniq(&1), fn name -> -String.length(name) end)
monsters = longest_first.(Enum.map(played, & &1.monster))

names =
  played
  |> Enum.flat_map(& &1.names)
  |> Enum.uniq()
  |> Enum.sort_by(fn {name, _} -> -String.length(name) end)

shape = fn line ->
  line = Enum.reduce(monsters, line, &String.replace(&2, &1, "M"))
  line = Enum.reduce(names, line, fn {name, as}, line -> String.replace(line, name, as) end)
  String.replace(line, ~r/\d[\d,.]*/, "N")
end

rounds = for fight <- played, {"Round" <> _ = head, line} <- fight.entries, do: {head, line}

clauses =
  for {_head, line} <- rounds,
      sentence <- String.split(String.trim_trailing(line, "."), ". "),
      clause <-
        String.split(
          String.replace(shape.(sentence), ~r/^As you cast, /, ""),
          ~r/, (and )?(?=(you|your|the)\b)/i
        ),
      do: {String.capitalize(String.first(clause)) <> String.slice(clause, 1..-1//1), line}

catalog =
  clauses
  |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
  |> Enum.map(fn {clause, lines} -> {clause, length(lines), hd(lines)} end)
  |> Enum.sort_by(fn {clause, count, _line} -> {-count, clause} end)

sentences = Enum.frequencies_by(rounds, fn {_head, line} -> length(String.split(line, ". ")) end)

IO.puts("#{length(played)} fights, #{length(rounds)} rounds, #{length(catalog)} clause shapes")
IO.puts("Sentences a round: #{inspect(Enum.sort(sentences))}\n")

for {clause, count, line} <- catalog, do: IO.puts("#{count}\t#{clause}\n\t\t#{line}")

IO.puts("\nRounds told in three sentences or more:")

rounds
|> Enum.map(&elem(&1, 1))
|> Enum.filter(&(length(String.split(&1, ". ")) > 2))
|> Enum.uniq()
|> Enum.take(5)
|> Enum.each(&IO.puts("  #{&1}"))

IO.puts("\nThe longest rounds:")

rounds
|> Enum.map(&elem(&1, 1))
|> Enum.uniq()
|> Enum.sort_by(&(-String.length(&1)))
|> Enum.take(5)
|> Enum.each(&IO.puts("  #{String.length(&1)}\t#{&1}"))

for set <- Enum.uniq(Enum.map(played, & &1.set)) do
  fight = Enum.find(played, &(&1.set == set and &1.gear == :best and &1.level == 13))
  IO.puts("\n#{set}, Level 13, against the #{fight.monster}:")
  for {head, line} <- fight.entries, do: IO.puts("  #{head}: #{line}")
end
