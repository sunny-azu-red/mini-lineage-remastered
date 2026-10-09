defmodule MiniLineage.Characters.VisitorTest do
  @moduledoc """
  A browser that never creates a character must leave nothing behind: a visitor is held in memory
  and written only once they choose a lineage, or the table fills with rows about nobody.

  Counted as deltas, because the browser suites share this database and do not roll back.
  """
  use MiniLineage.DataCase, async: false

  import Ecto.Query

  alias MiniLineage.Characters
  alias MiniLineage.Characters.Record
  alias MiniLineage.Game.{Actions, Player}

  defp rows, do: Repo.aggregate(Record, :count)

  defp raceless,
    do:
      Repo.aggregate(from(r in Record, where: is_nil(fragment("?->'race_id'", r.state))), :count)

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
    Characters.snapshot(session)

    assert rows() == before
    assert stored(session) == nil
  end

  test "a tick writes nothing — there is no health to regenerate", %{before: before} do
    session = visitor()
    [{pid, _}] = Registry.lookup(MiniLineage.Characters.Registry, session)

    send(pid, :tick)
    # One round trip, so the tick is certainly handled before the assertion.
    Characters.snapshot(session)

    assert rows() == before
    assert stored(session) == nil
  end

  test "a start that is refused persists nothing", %{before: before} do
    session = visitor()

    assert {{:error, :invalid, _}, _player} =
             Characters.mutate(session, &Actions.start(&1, "nonsense", "fighter", ""))

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

    Characters.mutate(session, &Actions.start(&1, "2", "fighter", "Arrived"))

    assert rows() == ctx.before + 1
    assert raceless() == ctx.raceless_before
    assert %Player{race_id: 2} = stored(session)
  end
end
