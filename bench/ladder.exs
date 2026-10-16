# A seeded run of every set up its village's ladder, once per weapon path its skills can use, played
# through the game's own actions: hunt, rest, buy the path's next gear the purse allows (selling what
# it replaced) and keep potions in stock, learn what the trainer offers. It reports where runs die,
# what the trainer costs and when, and what the shop costs and when. docs/balance.md reads it.
#
#   MIX_ENV=test mix run --no-start bench/ladder.exs [runs] [top level] [rest below %] [potions kept]
#     [--json path] [--only "Set name"] [--orders <pull share>,<fight share>]
#     [--unused "Skill,Skill"]
#   MIX_ENV=test mix run --no-start bench/ladder.exs --matrix <path prefix> [--final] [runs] [top level]
#     [--only "Set name"] ...: the study's settings in one go, each into <prefix>_<setting>.txt/.json
#
# Each run has its own seed, from its set and number, so a rule change moves only the runs it
# touches and two builds compare run for run (bench/compare.exs reads two --json files).
alias MiniLineage.Game.{Actions, Clock, Constants, Hunt, Player, Rng, Rules, Shop}

{opts, args} =
  OptionParser.parse!(System.argv(),
    strict: [
      json: :string,
      only: :string,
      orders: :string,
      unused: :string,
      matrix: :string,
      final: :boolean
    ]
  )

# Rules §20's battle orders every run gives, the start's unless named.
orders =
  case opts[:orders] do
    nil ->
      %{}

    given ->
      given
      |> String.split(",")
      |> Enum.map(&String.to_integer/1)
      |> then(fn [pull, fight] -> %{heal_pull_at: pull, heal_fight_at: fight} end)
  end
  |> Map.put(:unused, String.split(opts[:unused] || "", ",", trim: true))

defaults = [200, 20, 100, 20]

[runs, top, rest_below, kept] =
  Enum.map(args, &String.to_integer/1) ++ Enum.drop(defaults, length(args))

Application.ensure_all_started(:tz)

defmodule Ladder do
  # A path is a weapon type and the hands it is held in: a one-hander goes with a shield, and a
  # two-hander path carries one-handers only until its first two-hander is affordable.
  # The set's own starting weapons count as the path's too, or a sword path would never wield the
  # Squire's Sword it carries, and a shield bought early would leave it bare-handed.
  def paths(race, path) do
    {equipped, carried} = Rules.kit(race, path)
    kit = for name <- equipped ++ carried, item = Rules.item(name), item.kind == :weapon, do: item
    stock = Rules.stock(Rules.hometown(race), Rules.set(race, path)) ++ kit
    set = Rules.set(race, path).name

    types =
      if path == :mystic,
        do: ["staff"],
        else: Rules.lessons(set) |> Enum.flat_map(&Rules.skill_weapons(&1.skill)) |> Enum.uniq()

    for type <- types,
        hands <- [1, 2],
        held = Enum.filter(stock, &(&1.kind == :weapon and &1.type == type and &1.hands == hands)),
        held != [] do
      cheapest = held |> Enum.map(& &1.price) |> Enum.min()

      weapons =
        stock
        |> Enum.filter(
          &(&1.kind == :weapon and &1.type == type and
              (&1.hands == hands or (hands == 2 and &1.price < cheapest)))
        )
        |> Enum.map(& &1.name)

      label =
        if Enum.any?(stock, &(&1.type == type and &1.hands != hands)),
          do: "#{type} #{hands}h",
          else: type

      %{label: label, weapons: weapons, shield?: hands == 1}
    end
  end

  def worth(player, path, item) do
    cond do
      item.kind == :weapon and item.name not in path.weapons -> -1
      item.kind == :weapon and player.path == :mystic -> item.m_atk
      item.kind == :weapon -> item.p_atk
      item.kind == :shield -> if path.shield?, do: item.shield_def, else: -1
      item.kind == :armour -> if armour_ok?(player.path, item), do: item.p_def, else: -1
      item.kind == :jewellery -> item.m_def
      true -> -1
    end
  end

  @slots ~w(weapon chest legs necklace shield)a

  # What the village sells the set, the same all run long, so listed once a run.
  defp stock(player) do
    key = {:stock, player.location, player.race_id, player.path}

    with nil <- Process.get(key) do
      Process.put(key, Rules.stock(player.location, Rules.set(player.race_id, player.path)))
      Process.get(key)
    end
  end

  defp current(player, path, slot) do
    player
    |> Player.equipped()
    |> Enum.filter(&(&1.slot == slot))
    |> Enum.map(&worth(player, path, &1))
    |> Enum.max(fn -> -1 end)
  end

  defp best(player, path, slot) do
    player
    |> stock()
    |> Enum.filter(&(&1.slot == slot))
    |> Enum.map(&worth(player, path, &1))
    |> Enum.max(fn -> -1 end)
  end

  # Every slot the path fills holds the best its village sells.
  def kit?(player, path),
    do: Enum.all?(@slots, &(current(player, path, &1) >= best(player, path, &1)))

  # Puts on whatever of the kit the path holds, a Human Fighter's carried Squire's Dagger say.
  def arm(player, path) do
    Enum.reduce(player.items, player, fn item, p ->
      thing = Rules.item(item.name)

      if not item.equipped and thing.slot in @slots and
           worth(p, path, thing) > current(p, path, thing.slot),
         do: elem(Actions.equip(p, item.id), 0),
         else: p
    end)
  end

  # Best affordable upgrade for each slot, weapon first, bought and put on, the one it replaced sold.
  def shop(player, path) do
    Enum.reduce(@slots, player, fn slot, p ->
      now = current(p, path, slot)

      pick =
        stock(p)
        |> Enum.filter(
          &(&1.slot == slot and worth(p, path, &1) > now and Shop.price(&1) <= p.adena)
        )
        |> Enum.max_by(&worth(p, path, &1), fn -> nil end)

      if pick do
        {p, {:ok, _}} = Actions.buy(p, pick.name)
        {p, _} = Actions.equip(p, List.last(p.items).id)
        sell_spare(p)
      else
        p
      end
    end)
  end

  # A starting kit is worth nothing to a shop, so it stays carried.
  defp sell_spare(player) do
    Enum.reduce(player.items, player, fn item, p ->
      if item.equipped or Rules.stacks?(Rules.item(item.name)),
        do: p,
        else: elem(Actions.sell(p, item.id), 0)
    end)
  end

  # Rules §26: tops the stack up to the potions kept, ten at a time, once the gear is bought.
  def stock_potions(player, spent, kept) do
    have = player |> Player.potions() |> Enum.map(& &1.count) |> Enum.sum()

    if have < kept and player.adena >= 900 do
      {player, {:ok, _}} = Actions.buy(player, "Lesser Healing Potion", 10)
      stock_potions(player, spent + 900, kept)
    else
      {player, spent}
    end
  end

  defp armour_ok?(:fighter, item), do: item.type != "magic"
  defp armour_ok?(:mystic, item), do: item.type != "light" or item.slot not in [:chest, :legs]

  def train(player) do
    level = Player.level(player)

    Enum.reduce(lessons(player), player, fn lesson, p ->
      if lesson.learn_at <= level and Map.get(p.skills, lesson.skill, 0) == lesson.level - 1 and
           p.sp >= lesson.sp do
        {p, {:ok, _}} = Actions.learn(p, lesson.skill, lesson.level)
        p
      else
        p
      end
    end)
  end

  def lessons(player), do: Rules.lessons(Rules.set(player.race_id, player.path).name)

  def learned_all?(player),
    do: Enum.all?(lessons(player), &(Map.get(player.skills, &1.skill, 0) >= &1.level))

  # What the trainer is worth: SP on hand once trained on arriving at a level, each line's wait in
  # hunts from the level it is taught at, and the SP earned and spent.
  def note_training(reached, was, now, kills) do
    level = Player.level(now)

    waits =
      for {skill, known} <- now.skills,
          bought <- (Map.get(was.skills, skill, 0) + 1)..known//1,
          lesson = Enum.find(lessons(now), &(&1.skill == skill and &1.level == bought)),
          do: {lesson.learn_at, kills - Map.get(reached, lesson.learn_at, 0)}

    reached
    |> Map.put_new({:sp, level}, now.sp)
    |> Map.put_new({:earned, level}, was.sp + Map.get(reached, :spent, 0))
    |> Map.update(:waits, waits, &(waits ++ &1))
    |> Map.update(:spent, was.sp - now.sp, &(&1 + was.sp - now.sp))
  end

  # What the shop is worth: the level each of the path's weapons is first held at, and the level and
  # hunt the whole kit is.
  def note_gear(reached, player, path, kills) do
    level = Player.level(player)

    reached =
      player
      |> Player.equipped()
      |> Enum.filter(&(&1.name in path.weapons))
      |> Enum.reduce(reached, &Map.put_new(&2, {:tier, &1.name}, level))

    if kit?(player, path), do: Map.put_new(reached, :kit, {level, kills}), else: reached
  end

  # Ticks of rest (3 seconds each) until both bars are full.
  def rest(player, ticks \\ 0) do
    {rested, healed?} = Player.regenerate(player)
    if healed?, do: rest(rested, ticks + 1), else: {player, ticks}
  end
end

defmodule Run do
  # One run up the ladder, in its own process with its own dice and clock pin, so runs go in
  # parallel. The clock moves with the run, a tick of rest and a fight at a time, so auras fade.
  def play(race, path, weapons, seed, %{top: top, rest_below: rest_below, kept: kept} = settings) do
    # A run's heap grows all the way up the ladder; starting it large saves the collections.
    Process.flag(:min_heap_size, 1_000_000)
    :rand.seed(:exsss, seed)
    Rng.put_source(fn -> :rand.uniform() end)
    Clock.put_now(settings.start)
    {player, _} = Player.initialize(%Player{}, Constants.race(race), path, "Bench")
    player = Map.merge(player, settings.orders)
    player = Ladder.arm(player, weapons)
    reached = %{adena: 0, potions: 0, fight_ms: 0}

    Stream.iterate({player, 0, 0, reached}, fn {p, kills, ticks, reached} ->
      p = Ladder.shop(p, weapons)
      {p, potions} = Ladder.stock_potions(p, reached.potions, kept)
      reached = Ladder.note_gear(%{reached | potions: potions}, p, weapons, kills)
      trained = Ladder.train(p)
      reached = Ladder.note_training(reached, p, trained, kills)

      reached =
        if Ladder.learned_all?(trained),
          do: Map.put_new(reached, :list, {Player.level(trained), kills}),
          else: reached

      p = trained
      stats = Player.stats(p)

      # Resting means walking back to town, where the disengaging's seconds are spent at once.
      {p, rested} =
        if p.health * 100 < stats.max_hp * rest_below or p.mp * 100 < stats.max_mp * rest_below,
          do: Ladder.rest(%{p | combat: nil}),
          else: {p, 0}

      Clock.put_now(DateTime.add(Clock.now(), rested * 3))
      level = Player.level(p)
      purse = p.adena
      {p, {:ok, flash}} = Actions.hunt(p)
      Clock.put_now(DateTime.add(Clock.now(), round(flash.ms), :millisecond))

      reached = %{
        reached
        | adena: reached.adena + p.adena - purse,
          fight_ms: reached.fight_ms + flash.ms
      }

      reached =
        reached
        |> Map.put_new(Player.level(p), kills + 1)
        |> Map.put_new({:adena, Player.level(p)}, reached.adena)

      {p, kills + 1, ticks + rested, Map.put(reached, :died_at, if(p.dead, do: level))}
    end)
    |> Enum.find(fn {p, kills, _, _} -> p.dead or Player.level(p) >= top or kills > 5_000 end)
  end
end

defmodule Report do
  # A path's three lines of report and its row for --json, from its runs in run order.
  def path(name, race, path, weapons, results, runs, top) do
    deaths = Enum.filter(results, fn {p, _, _, _} -> p.dead end)

    died_at =
      deaths |> Enum.map(fn {_, _, _, r} -> r.died_at end) |> Enum.frequencies() |> Enum.sort()

    alive = results -- deaths

    avg = fn list, f ->
      if list == [], do: "-", else: round(Enum.sum(Enum.map(list, f)) / length(list))
    end

    # A level reached along the way, to the tenth, with the spread across runs.
    when_at = fn key ->
      case for({_, _, _, r} <- results, r[key], do: r[key]) do
        [] ->
          "never"

        hits ->
          levels = Enum.map(hits, &if(is_tuple(&1), do: elem(&1, 0), else: &1))
          mean = Float.round(Enum.sum(levels) / length(levels), 1)
          hunts = if is_tuple(hd(hits)), do: " hunt #{avg.(hits, &elem(&1, 1))}", else: ""
          "L#{mean} (#{Enum.min(levels)}–#{Enum.max(levels)})#{hunts}"
      end
    end

    killers =
      deaths
      |> Enum.map(fn {p, _, _, _} -> p.killer end)
      |> Enum.frequencies()
      |> Enum.sort_by(&(-elem(&1, 1)))
      |> Enum.take(4)

    first =
      "#{name} died #{length(deaths)}/#{runs} at #{inspect(died_at)} #{inspect(killers)} | " <>
        "to L#{top}: #{avg.(alive, fn {_, k, _, _} -> k end)} hunts, " <>
        "#{avg.(alive, fn {_, _, t, _} -> div(t * 3, 60) end)} min resting, " <>
        "#{avg.(alive, fn {_, _, _, r} -> div(round(r.fight_ms), 60_000) end)} min fighting, " <>
        "L5 at hunt #{avg.(results, fn {_, _, _, r} -> r[5] || 0 end)}, L10 at #{avg.(results, fn {_, _, _, r} -> r[10] || 0 end)}"

    banked =
      for l <- [5, 7, 10, 14, 15],
          do:
            "L#{l} #{avg.(Enum.filter(results, fn {_, _, _, r} -> r[{:sp, l}] end), fn {_, _, _, r} -> r[{:sp, l}] end)}"

    earned =
      for l <- [5, 7, 10, 14, 15],
          do: "L#{l} #{avg.(results, fn {_, _, _, r} -> r[{:earned, l}] || 0 end)}"

    waits =
      results
      |> Enum.flat_map(fn {_, _, _, r} -> Map.get(r, :waits, []) end)
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
      |> Enum.sort()
      |> Enum.map(fn {tier, w} -> "L#{tier} #{round(Enum.sum(w) / length(w))}/#{Enum.max(w)}" end)

    second =
      "  SP left once trained: #{Enum.join(banked, ", ")}, at the end #{avg.(alive, fn {p, _, _, _} -> p.sp end)} | " <>
        "earned by #{Enum.join(earned, ", ")} | wait in hunts (avg/max) #{Enum.join(waits, ", ")} | " <>
        "spent #{avg.(alive, fn {_, _, _, r} -> r[:spent] || 0 end)} | list learned #{when_at.(:list)}"

    purse =
      for l <- [5, 10, 12, 14, 15, 16, 17, 18, 20],
          hits = Enum.filter(results, fn {_, _, _, r} -> r[{:adena, l}] end),
          hits != [],
          do: "L#{l} #{avg.(hits, fn {_, _, _, r} -> r[{:adena, l}] end)}"

    # A weapon no better than one already bought is never held.
    tiers =
      for weapon <- weapons.weapons,
          held = when_at.({:tier, weapon}),
          held != "never",
          do: "#{weapon} #{held}"

    third =
      "  Adena earned by #{Enum.join(purse, ", ")} | #{Enum.join(tiers, ", ")} | " <>
        "kit #{when_at.(:kit)} | potions #{avg.(alive, fn {_, _, _, r} -> r.potions end)}, " <>
        "held at the end #{avg.(alive, fn {p, _, _, _} -> p.adena end)}"

    mean = fn list, f ->
      if list == [], do: nil, else: Enum.sum(Enum.map(list, f)) / length(list)
    end

    minutes = fn {_, _, t, r} -> (t * 3_000 + r.fight_ms) / 60_000 end

    row = %{
      set: Rules.set(race, path).name,
      path: weapons.label,
      runs: runs,
      deaths: length(deaths),
      died_at: Map.new(died_at, fn {level, n} -> {to_string(level), n} end),
      killers: Map.new(killers),
      hunts: mean.(alive, fn {_, k, _, _} -> k end),
      minutes: mean.(alive, minutes),
      # Each run's minutes to the top, nil for one that died, in run order, to compare run for run.
      minutes_by_run:
        Enum.map(results, fn {p, _, _, _} = run -> if !p.dead, do: minutes.(run) end),
      rest_minutes: mean.(alive, fn {_, _, t, _} -> t * 3 / 60 end),
      rounds_a_fight: mean.(alive, fn {_, k, _, r} -> r.fight_ms / Hunt.round_ms() / k end),
      potions: mean.(alive, fn {_, _, _, r} -> r.potions end),
      adena_at_end: mean.(alive, fn {p, _, _, _} -> p.adena end),
      sp_at_end: mean.(alive, fn {p, _, _, _} -> p.sp end),
      list_level: mean.(for({_, _, _, %{list: {l, _}}} <- results, do: l), & &1),
      kit_level: mean.(for({_, _, _, %{kit: {l, _}}} <- results, do: l), & &1)
    }

    {[first, second, third], row}
  end
end

start = ~U[2026-07-01 09:00:00Z]
setting = &%{top: top, rest_below: &1, kept: &2, orders: orders, start: start}

# --matrix writes the study's settings side by side, resting at 30% without potions (where most
# Fighters die, so it says little) only with --final.
studies =
  if label = opts[:matrix] do
    ([{"defaults", 100, 20}, {"harsh", 50, 0}] ++
       if(opts[:final], do: [{"harsher", 30, 0}], else: []) ++ [{"potions", 50, 20}])
    |> Enum.map(fn {name, rest_below, kept} ->
      {"#{label}_#{name}", setting.(rest_below, kept)}
    end)
  else
    [{opts[:json] && Path.rootname(opts[:json]), setting.(rest_below, kept)}]
  end

paths =
  for race <- [0, 2, 3, 1],
      path <- [:fighter, :mystic],
      opts[:only] in [nil, Rules.set(race, path).name],
      weapons <- Ladder.paths(race, path),
      do: {race, path, weapons, "#{Rules.set(race, path).name}, #{weapons.label}"}

# Every run of every setting in one queue, so no path waits on another's slowest run.
results =
  for {study, settings} <- studies, {race, path, weapons, name} <- paths, run <- 1..runs do
    {study, settings, race, path, weapons, name, run}
  end
  |> Task.async_stream(
    fn {study, settings, race, path, weapons, name, run} ->
      {{study, name}, run,
       Run.play(race, path, weapons, {:erlang.phash2(name), run, 7}, settings)}
    end,
    max_concurrency: System.schedulers_online(),
    ordered: false,
    timeout: :infinity
  )
  |> Enum.group_by(fn {:ok, {key, _, _}} -> key end, fn {:ok, {_, run, result}} ->
    {run, result}
  end)
  |> Map.new(fn {key, runs} ->
    {key, runs |> Enum.sort_by(&elem(&1, 0)) |> Enum.map(&elem(&1, 1))}
  end)

for {study, settings} <- studies do
  {lines, rows} =
    paths
    |> Enum.map(fn {race, path, weapons, name} ->
      Report.path(name, race, path, weapons, results[{study, name}], runs, top)
    end)
    |> Enum.unzip()

  text = lines |> List.flatten() |> Enum.map_join(&(&1 <> "\n"))
  settings = Map.update!(settings, :start, &DateTime.to_iso8601/1)
  json = JSON.encode!(%{settings: settings, rows: rows})

  if opts[:matrix] do
    File.write!(study <> ".txt", text)
    File.write!(study <> ".json", json)
    IO.puts("#{study}: #{length(paths)} paths, #{runs} runs each")
  else
    IO.write(text)
    if path = opts[:json], do: File.write!(path, json)
  end
end
