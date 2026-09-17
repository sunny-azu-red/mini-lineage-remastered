defmodule MiniLineage.Characters.VisitorTest do
  @moduledoc """
  A browser that never creates a character must leave nothing behind.

  The sweep deletes runs that have a session and no race, so this is the property that keeps that
  DELETE from ever having work to do: a visitor is held in memory and written only once they
  choose a lineage. Without it the table fills with rows about nobody.

  Counted as deltas rather than totals — the browser suites share this database and do not roll
  back, so the table is rarely empty when a test starts.
  """
  use MiniLineage.DataCase, async: false

  import Ecto.Query

  alias MiniLineage.Characters
  alias MiniLineage.Characters.Record
  alias MiniLineage.Game.{Actions, Player}

  defp rows, do: Repo.aggregate(Record, :count)
  defp raceless, do: Repo.aggregate(from(r in Record, where: is_nil(r.race_id)), :count)

  defp visitor do
    session = Characters.new_session_id()
    on_exit(fn -> Characters.forget(session) end)
    hold(session)

    session
  end

  setup do
    {:ok, before: rows(), raceless_before: raceless()}
  end

  test "reading a visitor's state writes nothing", %{before: before} do
    session = visitor()

    Characters.snapshot(session)
    Characters.character_id(session)
    Characters.snapshot(session)

    assert rows() == before
    assert stored(session) == nil
  end

  test "a tick writes nothing — there is no health to regenerate", %{before: before} do
    session = visitor()
    [{pid, _}] = Registry.lookup(MiniLineage.Characters.Registry, session)

    send(pid, :tick)
    send(pid, :expiry)
    # One round trip, so both messages are certainly handled before the assertion.
    Characters.snapshot(session)

    assert rows() == before
    assert stored(session) == nil
  end

  test "every action a visitor can attempt is refused, and none of them persist", %{
    before: before
  } do
    session = visitor()

    results =
      for fun <- [
            &Actions.fight/1,
            &Actions.suicide/1,
            &Actions.cheat/1,
            &Actions.purchase(&1, "food", "0"),
            &Actions.set_screen(&1, "home"),
            &Actions.start(&1, "nonsense", "")
          ] do
        Characters.mutate(session, fun)
      end

    # The cheat is silent by design, so it answers {:ok, nil} rather than refusing out loud.
    assert Enum.all?(results, &(&1 == {:ok, nil} or match?({:error, _, _}, &1)))
    assert rows() == before
    assert stored(session) == nil
  end

  test "and the process stopping flushes nothing", %{before: before} do
    session = visitor()

    Characters.snapshot(session)
    Characters.forget_process(session)

    assert rows() == before
    assert stored(session) == nil
  end

  test "choosing a lineage is what writes the row, with a race from the first byte", ctx do
    session = visitor()
    assert stored(session) == nil

    Characters.mutate(session, &Actions.start(&1, "2", "Arrived"))

    assert rows() == ctx.before + 1
    assert raceless() == ctx.raceless_before
    assert %Player{race_id: 2} = stored(session)
  end

  test "starting over writes no row for the empty character that replaces the run", ctx do
    session = visitor()
    Characters.mutate(session, &Actions.start(&1, "0", "First"))
    Characters.mutate(session, &{Player.kill(&1), :ok})

    Characters.archive(session)
    hold(session)
    # The fresh character exists only in memory until it chooses a lineage of its own.
    Characters.snapshot(session)
    Characters.forget_process(session)

    assert rows() == ctx.before + 1, "the archived run, and nothing for the empty one after it"
    assert raceless() == ctx.raceless_before
    assert stored(session) == nil, "the archived run gave up this session"
  end
end
