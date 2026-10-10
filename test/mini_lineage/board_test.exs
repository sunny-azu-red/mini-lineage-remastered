defmodule MiniLineage.BoardTest do
  @moduledoc """
  The Halls, a view of the characters rather than a table of their own. What matters most is not
  the ordering: a run appears the moment it starts and keeps its place when it ends, and the board
  never carries a session id, the secret that plays a character.
  """
  use MiniLineage.DataCase, async: false

  import Ecto.Query

  alias MiniLineage.{Board, Characters}
  alias MiniLineage.Characters.{Record, Store}
  alias MiniLineage.Game.{Constants, Player}

  setup do
    Repo.delete_all(Record)
    :ok
  end

  # Written straight through the store so no dice are rolled: what is tested is the ordering and
  # the filtering, not what a hunt happens to award.
  defp run(name, opts \\ []) do
    session = Characters.new_session_id()
    id = Store.new_id()
    race = Constants.race(opts[:race_id] || 0)
    {player, _} = Player.initialize(%Player{}, race, :fighter, name)
    player = %{player | experience: opts[:xp] || 0, adena: opts[:adena] || 0}

    if opts[:dead],
      do: Store.retire(id, %{player | dead: true, killer: "Wolf"}),
      else: Store.save(id, session, player)

    %{id: id, session: session}
  end

  defp names(race_id \\ nil), do: Enum.map(Map.get(Board.current(), race_id, []), & &1.name)

  describe "the ordering" do
    test "is EXP, which is level and then EXP, then wealth, and the two are not swapped" do
      run("Low", xp: 10, adena: 999)
      run("High", xp: 900, adena: 1)
      run("Rich", xp: 900, adena: 500)

      assert names() == ["Rich", "High", "Low"]
    end

    test "breaks a dead heat in favour of whoever got there first" do
      %{id: second} = run("Second", xp: 500, adena: 5)
      run("First", xp: 500, adena: 5)
      earlier = DateTime.add(DateTime.utc_now(), -60, :second)
      Repo.update_all(from(r in Record, where: r.id != ^second), set: [inserted_at: earlier])

      assert names() == ["First", "Second"]
    end

    test "and caps each board" do
      for n <- 1..(Board.limit() + 3), do: run("Hero#{n}", xp: n * 10)

      assert length(names()) == Board.limit()
    end
  end

  describe "who is on it" do
    test "a run appears the moment it chooses a race, alive, with a session" do
      run("Fresh")

      assert [%{name: "Fresh", dead: false, active: true, level: 1}] = Board.current()[nil]
    end

    test "and stays when it dies, fallen and without a session" do
      run("Fallen", xp: 100, dead: true)

      assert [%{name: "Fallen", dead: true, active: false}] = Board.current()[nil]
    end

    test "and stays when it goes missing" do
      %{id: id} = run("Missing", xp: 100)
      Repo.update_all(from(r in Record, where: r.id == ^id), set: [session_id: nil])

      assert [%{name: "Missing", dead: false, active: false}] = Board.current()[nil]
    end

    test "a lineage's board holds only its own" do
      run("Human", xp: 5, race_id: 0)
      run("Elf", xp: 9, race_id: 2)

      assert names(2) == ["Elf"]
      assert names() == ["Elf", "Human"]
    end

    test "only the overall top three wear a medal, on every board they appear on" do
      for n <- 1..4, do: run("Hero#{n}", xp: n * 100, race_id: rem(n, 2) * 2)

      medals = Map.new(Board.current()[nil], &{&1.name, &1.medal})
      assert medals == %{"Hero4" => 1, "Hero3" => 2, "Hero2" => 3, "Hero1" => nil}
      assert Enum.find(Board.current()[2], &(&1.name == "Hero3")).medal == 2
    end
  end

  test "a row is a plain map that carries no session, only whether there is one" do
    %{session: session} = run("Secret")

    for {_filter, rows} <- Board.current(), row <- rows do
      refute is_struct(row)
      refute Map.has_key?(row, :session_id)
      refute session in Map.values(row)
    end
  end

  describe "the process" do
    setup do
      start_supervised!(Board)
      Board.subscribe()
      :ok
    end

    test "pushes a write once its window closes" do
      run("Climber", xp: 50)
      Board.character_changed()

      assert_receive {:board, %{nil => [%{name: "Climber"}]}}, 2_000
    end

    test "and pushes nothing when nothing on it moved" do
      Board.character_changed()

      refute_receive {:board, _}, 1_000
    end
  end
end
