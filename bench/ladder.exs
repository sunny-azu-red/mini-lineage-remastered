# A seeded run of every set up its village's ladder, played through the game's own actions: hunt,
# rest, buy the next gear the purse allows and keep potions in stock, learn what the trainer offers.
# It reports where runs die.
#
#   MIX_ENV=test mix run --no-start bench/ladder.exs [runs] [top level] [rest below %] [potions kept]
alias MiniLineage.Game.{Actions, Clock, Constants, Hunt, Player, Rng, Rules, Shop}

{runs, top, rest_below} =
  case System.argv() do
    [r, t, b, k] ->
      Process.put(:kept, String.to_integer(k))
      {String.to_integer(r), String.to_integer(t), String.to_integer(b)}

    [r, t, b] -> {String.to_integer(r), String.to_integer(t), String.to_integer(b)}
    [r, t] -> {String.to_integer(r), String.to_integer(t), 100}
    _ -> {40, 15, 100}
  end

Application.ensure_all_started(:tz)
# The clock moves with the run, a tick of rest and a round of a fight at a time, so auras fade.
start = ~U[2026-07-01 09:00:00Z]
:rand.seed(:exsss, {7, 7, 7})
Rng.put_source(fn -> :rand.uniform() end)

defmodule Ladder do
  # The weapon types a set's first skill wants, best bought first.
  def wants(path, skill) do
    case {path, skill} do
      {:mystic, _} -> nil
      {_, "Power Strike"} -> ["sword"]
      {_, "Power Shot"} -> ["bow"]
      {_, "Mortal Blow"} -> ["dagger"]
      {_, "Iron Punch"} -> ["fists"]
    end
  end

  # Best affordable upgrade for each slot, weapon first, bought and put on.
  def shop(player) do
    stock = Rules.stock(player.location)
    types = wants(player.path, Rules.first_skill(player.race_id, player.path).name)
    equipped = Player.equipped(player)

    worth = fn item ->
      cond do
        item.kind == :weapon and player.path == :mystic -> item.m_atk
        item.kind == :weapon -> if item.type in types, do: item.p_atk, else: -1
        item.kind == :armour -> if armour_ok?(player.path, item), do: item.p_def, else: -1
        item.kind == :jewellery -> item.m_def
        true -> -1
      end
    end

    current = fn slot ->
      equipped |> Enum.filter(&(&1.slot == slot)) |> Enum.map(worth) |> Enum.min(fn -> 0 end)
    end

    slots = ~w(weapon chest legs necklace)a

    Enum.reduce(slots, player, fn slot, p ->
      best =
        stock
        |> Enum.filter(
          &(&1.slot == slot and worth.(&1) > current.(slot) and Shop.price(&1) <= p.adena)
        )
        |> Enum.max_by(worth, fn -> nil end)

      if best &&
           (slot != :weapon or player.path == :mystic or best.hands == 1 or
              best.type in ~w(bow fists)) do
        {p, {:ok, _}} = Actions.buy(p, best.name)
        bought = List.last(p.items)
        {p, _} = Actions.equip(p, bought.id)
        p
      else
        p
      end
    end)
  end

  # Rules §26: tops the stack up to the potions kept, ten at a time, once the gear is bought.
  def stock_potions(player) do
    kept = Process.get(:kept, 20)
    have = player |> Player.potions() |> Enum.map(& &1.count) |> Enum.sum()

    if have < kept and player.adena >= 900 do
      {player, {:ok, _}} = Actions.buy(player, "Lesser Healing Potion", 10)
      stock_potions(player)
    else
      player
    end
  end

  defp armour_ok?(:fighter, item), do: item.type != "magic"
  defp armour_ok?(:mystic, item), do: item.type != "light" or item.slot not in [:chest, :legs]

  def train(player) do
    level = Player.level(player)
    set = Rules.set(player.race_id, player.path).name

    Enum.reduce(Rules.lessons(set), player, fn lesson, p ->
      if lesson.learn_at <= level and Map.get(p.skills, lesson.skill, 0) == lesson.level - 1 and
           p.sp >= lesson.sp do
        {p, {:ok, _}} = Actions.learn(p, lesson.skill, lesson.level)
        p
      else
        p
      end
    end)
  end

  # Ticks of rest (3 seconds each) until both bars are full.
  def rest(player, ticks \\ 0) do
    {rested, healed?} = Player.regenerate(player)
    if healed?, do: rest(rested, ticks + 1), else: {player, ticks}
  end
end

for race <- [0, 2, 3, 1], path <- [:fighter, :mystic] do
  name = Rules.set(race, path).name

  results =
    for _ <- 1..runs do
      Clock.put_now(start)
      {player, _} = Player.initialize(%Player{}, Constants.race(race), path, "Bench")

      Stream.iterate({player, 0, 0, %{}}, fn {p, kills, ticks, reached} ->
        p = p |> Ladder.shop() |> Ladder.stock_potions() |> Ladder.train()
        stats = Player.stats(p)

        # Resting means walking back to town, where the disengaging's seconds are spent at once.
        {p, rested} =
          if p.health * 100 < stats.max_hp * rest_below or p.mp * 100 < stats.max_mp * rest_below,
            do: Ladder.rest(%{p | combat: nil}),
            else: {p, 0}

        Clock.put_now(DateTime.add(Clock.now(), rested * 3))
        level = Player.level(p)
        {p, {:ok, flash}} = Actions.hunt(p)
        rounds = length(Map.get(flash, :log, [nil])) - 1
        Clock.put_now(DateTime.add(Clock.now(), round(rounds * Hunt.round_ms()), :millisecond))
        reached = Map.put_new(reached, Player.level(p), kills + 1)
        {p, kills + 1, ticks + rested, Map.put(reached, :died_at, if(p.dead, do: level))}
      end)
      |> Enum.find(fn {p, kills, _, _} -> p.dead or Player.level(p) >= top or kills > 5_000 end)
    end

  deaths = Enum.filter(results, fn {p, _, _, _} -> p.dead end)

  died_at =
    deaths |> Enum.map(fn {_, _, _, r} -> r.died_at end) |> Enum.frequencies() |> Enum.sort()

  alive = results -- deaths

  avg = fn list, f ->
    if list == [], do: "-", else: round(Enum.sum(Enum.map(list, f)) / length(list))
  end

  killers =
    deaths
    |> Enum.map(fn {p, _, _, _} -> p.killer end)
    |> Enum.frequencies()
    |> Enum.sort_by(&(-elem(&1, 1)))
    |> Enum.take(4)

  IO.puts(
    "#{String.pad_trailing(name, 14)} died #{length(deaths)}/#{runs} at #{inspect(died_at)} #{inspect(killers)} | " <>
      "to L#{top}: #{avg.(alive, fn {_, k, _, _} -> k end)} hunts, " <>
      "#{avg.(alive, fn {_, _, t, _} -> div(t * 3, 60) end)} min resting, " <>
      "L5 at hunt #{avg.(results, fn {_, _, _, r} -> r[5] || 0 end)}, L10 at #{avg.(results, fn {_, _, _, r} -> r[10] || 0 end)}"
  )
end
