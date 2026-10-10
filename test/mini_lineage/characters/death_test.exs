defmodule MiniLineage.Characters.DeathTest do
  @moduledoc """
  Rules §21 where it is kept: a run that dies is written with its killer and gives up its session in
  the same step, so its row stays for the Halls and no browser can load it again, and the browser
  goes on as a visitor under a fresh id.
  """
  use MiniLineage.DataCase, async: false

  alias MiniLineage.Characters
  alias MiniLineage.Characters.{Record, Store}
  alias MiniLineage.Game.{Actions, Player}

  setup do
    session = Characters.new_session_id()
    on_exit(fn -> Characters.forget(session) end)

    {{:ok, _flash}, _player} =
      Characters.mutate(session, &Actions.start(&1, 0, "fighter", "Doomed"))

    %{session: session, id: Characters.character_id(session)}
  end

  defp die(player), do: {%{player | health: 0, dead: true, killer: "Wolf"}, :ok}

  test "the row is kept, dead, with what killed it, and without its session", %{
    session: session,
    id: id
  } do
    Characters.mutate(session, &die/1)

    record = Repo.get!(Record, id)
    assert record.dead
    assert record.state["killer"] == "Wolf"
    assert record.session_id == nil
    assert Store.load_by_session(session) == nil
  end

  test "and the browser goes on as a visitor, under a new id", %{session: session, id: id} do
    {:ok, player} = Characters.mutate(session, &die/1)

    assert player == %Player{}
    assert Characters.snapshot(session) == %Player{}
    refute Characters.character_id(session) == id
  end

  test "another tab is told, and follows", %{session: session} do
    Characters.subscribe(session)
    Characters.mutate(session, &die/1)

    assert_receive {:character_updated, %Player{race_id: nil}}
  end
end
