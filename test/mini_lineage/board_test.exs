defmodule MiniLineage.BoardTest do
  @moduledoc """
  The Halls of Champions, which are now a view of the characters rather than a table of their own.

  Two things matter most here and neither is the ordering. A run must appear the moment it starts
  and keep its place when it ends, because that is the whole point of the redesign. And the board
  must never render a session id — it is the secret that lets a browser play a character, and the
  board is the one place every character is listed by name.
  """
  use MiniLineage.DataCase, async: false

  alias MiniLineage.{Board, Characters}
  alias MiniLineage.Characters.{Record, Store}
  alias MiniLineage.Game.{Constants, Player}

  setup do
    Repo.query!("DELETE FROM battle_log")
    Repo.query!("DELETE FROM characters")

    :ok
  end

  # Written straight through the store so no dice are rolled: what is being tested is the ordering
  # and the filtering, not what a fight happens to award.
  defp run(name, opts) do
    session = Characters.new_session_id()
    id = Store.new_id()

    {player, _} =
      Player.initialize(%Player{}, Constants.race(opts[:race_id] || 0), name)

    player = %{
      player
      | experience: opts[:xp] || 0,
        adena: opts[:adena] || 0,
        dead: opts[:dead] || false,
        coward: opts[:coward] || false,
        cheated: opts[:cheated] || false
    }

    :ok = Store.save(id, session, player)
    %{id: id, session: session}
  end

  defp names(race_id \\ nil), do: Enum.map(Map.get(Board.current(), race_id, []), & &1.name)

  # Every repo query the block provokes, wherever it was run from. Counting them is the only way to
  # assert that a refresh read nothing: the board it pushes looks the same either way.
  defp measuring(fun) do
    handler = {__MODULE__, make_ref()}
    parent = self()

    :telemetry.attach(
      handler,
      [:mini_lineage, :repo, :query],
      fn _event, _measure, meta, _ -> send(parent, {handler, meta.query}) end,
      nil
    )

    result = fun.()
    :telemetry.detach(handler)

    {result, drain(handler, [])}
  end

  defp drain(handler, acc) do
    receive do
      {^handler, query} -> drain(handler, [query | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end

  describe "the ordering" do
    test "is experience, then wealth, and the two are not swapped" do
      run("Low", xp: 10, adena: 999)
      run("High", xp: 900, adena: 1)
      run("Rich", xp: 900, adena: 500)

      assert names() == ["Rich", "High", "Low"]
    end

    test "breaks a dead heat in favour of whoever got there first" do
      run("First", xp: 500, adena: 5)
      # A later row with identical standing must rank below it, however the ids happen to sort.
      Process.sleep(5)
      run("Second", xp: 500, adena: 5)

      assert names() == ["First", "Second"]
    end

    test "and caps at the configured limit" do
      for n <- 1..(Constants.highscores_limit() + 5), do: run("Hero#{n}", xp: n * 10)

      assert length(names()) == Constants.highscores_limit()
    end
  end

  describe "who is on it" do
    test "a run appears the moment it chooses a race, still alive" do
      run("Fresh", xp: 0)

      assert names() == ["Fresh"]
      assert [%{dead: false}] = Map.get(Board.current(), nil)
    end

    test "and stays when the run ends" do
      run("Fallen", xp: 100, dead: true)

      assert names() == ["Fallen"]
    end

    test "and stays after it is archived, which is what retirement does" do
      %{session: session} = run("Retired", xp: 100, dead: true)
      Characters.archive(session)

      assert names() == ["Retired"]
    end

    test "a visitor who never chose a race is nobody" do
      session = Characters.new_session_id()
      :ok = Store.save(Store.new_id(), session, %Player{})

      assert names() == []
    end

    test "a coward is barred, and so is a cheat" do
      run("Honest", xp: 100, dead: true)
      run("Coward", xp: 9_000, dead: true, coward: true)
      run("Cheat", xp: 9_000, dead: true, cheated: true)

      assert names() == ["Honest"]
    end

    test "but a barred run still has its own page — it is not erased" do
      %{id: id} = run("Coward", xp: 9_000, dead: true, coward: true)

      entry = Board.entry(id)

      assert entry.name == "Coward"
      assert entry.disqualified
      assert names() == [], "a barred run is still absent from the board"
    end
  end

  describe "starting over" do
    test "keeps the browser's session and gives it a different character" do
      %{id: first, session: session} = run("First", xp: 500, dead: true)

      Characters.archive(session)
      second = Characters.character_id(session)

      # The session names the browser, not the run — which is why this needs no new cookie.
      assert second != first
      assert Repo.get(Record, first).session_id == nil
      refute Player.started?(Characters.snapshot(session))
      on_exit(fn -> Characters.forget(session) end)
    end

    test "leaves the finished run standing in the Halls" do
      %{id: first, session: session} = run("Finished", xp: 500, dead: true)
      Characters.archive(session)
      on_exit(fn -> Characters.forget(session) end)

      assert Board.entry(first).name == "Finished"
      assert names() == ["Finished"]
    end

    test "and the next run joins it rather than replacing it" do
      %{session: session} = run("First", xp: 500, dead: true)
      Characters.archive(session)
      on_exit(fn -> Characters.forget(session) end)

      Characters.mutate(session, fn p ->
        {p, _} = Player.initialize(p, Constants.race(2), "Second")
        {%{p | experience: 100}, :ok}
      end)

      assert names() == ["First", "Second"]
    end
  end

  describe "the date a row shows" do
    test "is when the run was last played, not when the character was born" do
      %{id: id, session: session} = run("Aging", xp: 10)
      born = Board.entry(id).inserted_at

      # Time passes, then the run ends. The old board stamped its rows when a legacy was written;
      # `inserted_at` on a character means something else entirely — the day it was rolled.
      Process.sleep(1_100)
      Characters.mutate(session, &{%{&1 | dead: true, experience: 900}, :ok})
      on_exit(fn -> Characters.forget(session) end)

      entry = Board.entry(id)

      assert entry.inserted_at == born
      assert DateTime.compare(entry.updated_at, born) == :gt
    end

    test "and archiving the run does not move it" do
      %{id: id, session: session} = run("Done", xp: 10, dead: true)
      ended = Board.entry(id).updated_at

      Characters.archive(session)
      on_exit(fn -> Characters.forget(session) end)

      # Retiring is bookkeeping, not play — it must not restamp a finished run.
      assert Board.entry(id).updated_at == ended
    end
  end

  describe "whether a run is still being played" do
    test "is on the row itself, so the board can style it", %{} do
      run("Alive", xp: 10)
      run("Fallen", xp: 5, dead: true)

      assert Map.new(Map.get(Board.current(), nil), &{&1.name, &1.dead}) ==
               %{"Alive" => false, "Fallen" => true}
    end
  end

  describe "a run nobody can play again" do
    test "is missing rather than going, once its session is gone" do
      %{id: id, session: session} = run("Wanderer", xp: 500)
      assert Board.entry(id).active, "a run with a session is still going"

      # What the 30-day retirement does: it takes the session and kills nothing.
      Characters.archive(session)
      on_exit(fn -> Characters.forget(session) end)

      entry = Board.entry(id)

      refute entry.dead, "retirement must not pretend the character died"
      refute entry.active, "but it can never be played again"
    end

    test "and the board never says how, only whether" do
      %{id: id, session: session} = run("Wanderer", xp: 500)
      Characters.archive(session)
      on_exit(fn -> Characters.forget(session) end)

      entry = Board.entry(id)

      # `active` is the ONLY thing said about the session. The secret itself never leaves the row.
      refute Map.has_key?(entry, :session_id)
      refute session in Map.values(entry)
    end
  end

  describe "who is online right now" do
    test "is a run somebody has open, not merely one that is alive" do
      # Written straight to the store, so no process is holding it.
      %{id: idle} = run("Idle", xp: 10)

      session = Characters.new_session_id()

      Characters.mutate(session, fn p ->
        {p, _} = Player.initialize(p, Constants.race(1), "Held")
        {p, :ok}
      end)

      held = Characters.character_id(session)
      Characters.attach(session, self())
      on_exit(fn -> Characters.forget(session) end)

      online = Characters.online()

      assert MapSet.member?(online, held)
      refute MapSet.member?(online, idle)
    end

    test "and the board carries it on the row" do
      session = Characters.new_session_id()

      Characters.mutate(session, fn p ->
        {p, _} = Player.initialize(p, Constants.race(1), "Held")
        {p, :ok}
      end)

      Characters.attach(session, self())
      on_exit(fn -> Characters.forget(session) end)
      run("Idle", xp: 10_000)

      assert Map.new(Map.get(Board.current(), nil), &{&1.name, &1.online}) ==
               %{"Held" => true, "Idle" => false}
    end

    test "a single lookup has the same shape as a board row" do
      # The shapes must not drift: the template reads one component for both.
      %{id: id} = run("Solo", xp: 10)

      assert Map.keys(Board.entry(id)) |> Enum.sort() ==
               Map.keys(hd(Map.get(Board.current(), nil))) |> Enum.sort()
    end
  end

  describe "the medals" do
    test "go to the first three, and no further" do
      for {name, xp} <- [{"Gold", 900}, {"Silver", 800}, {"Bronze", 700}, {"Fourth", 600}] do
        run(name, xp: xp)
      end

      assert Enum.map(Map.get(Board.current(), nil), &{&1.name, &1.medal}) ==
               [{"Gold", 1}, {"Silver", 2}, {"Bronze", 3}, {"Fourth", nil}]
    end

    test "mean the same thing on a lineage's own board as on the full one" do
      # Global, not per-list. Three Orcs hold every medal, so the best Elf tops the Elf board
      # wearing nothing — which is the whole point of the choice.
      for xp <- [900, 800, 700], do: run("Orc#{xp}", race_id: 1, xp: xp)
      run("BestElf", race_id: 2, xp: 100)

      assert Enum.map(Map.get(Board.current(), 2), &{&1.name, &1.medal}) == [{"BestElf", nil}]
      assert Enum.map(Map.get(Board.current(), 1), & &1.medal) == [1, 2, 3]
    end

    test "and a board with fewer than three runs awards only what it has" do
      run("Only", xp: 10)

      assert Enum.map(Map.get(Board.current(), nil), & &1.medal) == [1]
    end
  end

  describe "the race filter" do
    test "shows only that race, and All shows everyone" do
      run("Orcish", race_id: 1, xp: 10)
      run("Elven", race_id: 2, xp: 20)

      assert names(1) == ["Orcish"]
      assert names(2) == ["Elven"]
      assert names() == ["Elven", "Orcish"]
    end
  end

  describe "what the board hands out" do
    test "never includes the session that plays the character" do
      %{session: session} = run("Named", xp: 10)
      [entry] = Map.get(Board.current(), nil)

      # The strongest form of this: the secret does not appear ANYWHERE in the entry, under any
      # key. A board link must never be usable as a cookie.
      refute session in Map.values(entry)
      refute Map.has_key?(entry, :session_id)
      assert entry.id != session
    end

    test "and carries the level, derived rather than stored" do
      run("Levelled", xp: 5_000)
      [entry] = Map.get(Board.current(), nil)

      assert entry.level == MiniLineage.Game.Math.level_for_xp(5_000)
    end

    test "an id nobody owns is simply not a champion" do
      assert Board.entry("no-such-id") == nil
    end
  end

  describe "going live" do
    # The board process is not started in :test — its timer would fire queries from outside the
    # sandbox — so this starts one for the test and lets it own the connection.
    setup do
      pid = start_supervised!(MiniLineage.Board)
      Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)

      :ok
    end

    test "pushes the whole board to every viewer when a character is written" do
      Board.subscribe()
      run("Climber", xp: 10)

      Board.character_changed()

      assert_receive {:board, boards}, 2_000
      assert Enum.map(Map.get(boards, nil), & &1.name) == ["Climber"]
    end

    test "coalesces a burst into one push, so a flurry of fights is not a flurry of queries" do
      Board.subscribe()
      run("Busy", xp: 10)

      for _ <- 1..20, do: Board.character_changed()

      assert_receive {:board, _}, 2_000
      # Nothing more within a second: twenty writes produced one recomputation, not twenty.
      refute_receive {:board, _}, 1_000
    end

    test "a mount or an unmount lights a dot and costs nothing at all" do
      # Presence is the commonest refresh there is — every page load is one on the way in and one
      # on the way out — and it is the one thing on a row that moves without anybody writing.
      %{id: id} = run("Watched", xp: 10)
      Board.subscribe()
      Board.character_changed()
      assert_receive {:board, before}, 2_000
      refute Enum.find(Map.get(before, nil), &(&1.id == id)).online

      session = Characters.new_session_id()

      Characters.mutate(session, fn p ->
        {p, _} = Player.initialize(p, Constants.race(1), "Holder")
        {p, :ok}
      end)

      Characters.attach(session, self())
      on_exit(fn -> Characters.forget(session) end)
      assert_receive {:board, _}, 2_000

      {boards, queries} =
        measuring(fn ->
          Board.presence_changed()
          assert_receive {:board, pushed}, 2_000
          pushed
        end)

      assert queries == [], "a presence refresh ran #{length(queries)} quer(y/ies)"
      assert Enum.find(Map.get(boards, nil), &(&1.name == "Holder")).online
    end

    test "but a write in the same window is still a write, and recomputes" do
      Board.subscribe()
      run("First", xp: 10)
      Board.character_changed()
      assert_receive {:board, _}, 2_000

      run("Second", xp: 10_000)

      {boards, queries} =
        measuring(fn ->
          # Presence first, so the window is opened by the cheap signal and claimed by the write.
          Board.presence_changed()
          Board.character_changed()
          assert_receive {:board, pushed}, 2_000
          pushed
        end)

      refute queries == [], "a window carrying a write must reach the database"
      assert Enum.map(Map.get(boards, nil), & &1.name) == ["Second", "First"]
    end

    test "and a viewer who arrives late is served the same board, without a query of their own" do
      # `current/0` answers from the cache, so it is at most one coalesce window behind — which is
      # the trade: one recomputation per window for everybody, rather than one query per viewer.
      Board.subscribe()
      run("Already", xp: 10)
      Board.character_changed()
      assert_receive {:board, pushed}, 2_000

      assert Board.current() == pushed
      assert Enum.map(Map.get(Board.current(), nil), & &1.name) == ["Already"]
    end
  end

  describe "the generated columns" do
    test "follow the document without anyone writing them" do
      %{id: id, session: session} = run("Before", xp: 1, adena: 1)

      Characters.mutate(session, fn player ->
        {%{player | name: "After", experience: 777, adena: 42, dead: true}, :ok}
      end)

      on_exit(fn -> Characters.forget(session) end)
      entry = Board.entry(id)

      assert entry.name == "After"
      assert entry.total_xp == 777
      assert entry.adena == 42
      assert entry.dead
    end
  end
end
