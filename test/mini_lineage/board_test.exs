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

  describe "the ordering" do
    test "is experience, then wealth, and the two are not swapped" do
      run("Low", xp: 10, adena: 999)
      run("High", xp: 900, adena: 1)
      run("Rich", xp: 900, adena: 500)

      assert names() == ["Rich", "High", "Low"]
    end

    test "breaks a dead heat in favour of whoever got there first" do
      first = run("First", xp: 500, adena: 5)
      # A later row with identical standing must rank below it, however the ids happen to sort.
      Process.sleep(5)
      run("Second", xp: 500, adena: 5)

      assert names() == ["First", "Second"]
      assert Board.rank_of(Board.entry(first.id)) == 1
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
      assert Board.rank_of(entry) == nil, "a barred run has no rank to show"
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

  describe "the race filter" do
    test "shows only that race, and All shows everyone" do
      run("Orcish", race_id: 1, xp: 10)
      run("Elven", race_id: 2, xp: 20)

      assert names(1) == ["Orcish"]
      assert names(2) == ["Elven"]
      assert names() == ["Elven", "Orcish"]
    end
  end

  describe "a player's own place" do
    test "counts everyone genuinely ahead of them" do
      for n <- 1..5, do: run("Hero#{n}", xp: n * 100)
      mine = run("Mine", xp: 250)

      # 500 and 400 are ahead; 300 is not — 250 sits fourth.
      assert Board.rank_of(Board.entry(mine.id)) == 4
    end

    test "and is first for the only run there is" do
      %{id: id} = run("Alone", xp: 1)

      assert Board.rank_of(Board.entry(id)) == 1
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
