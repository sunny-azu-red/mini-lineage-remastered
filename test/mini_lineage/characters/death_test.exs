defmodule MiniLineage.Characters.DeathTest do
  @moduledoc """
  Rules §21 where it is kept: a run that dies is written with its killer and where it fell, and
  stays the browser's, a ghost that may look and do nothing else, until it begins again. Then it
  gives up its session in one step, so its row stays for the Halls and no browser can load it, and
  the browser goes on as a visitor under a fresh id.
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

  defp die(player),
    do:
      {%{
         player
         | health: 0,
           dead: true,
           killer: "Wolf",
           fell_at: "obelisk-of-victory"
       }, :ok}

  test "the row is kept, dead, with what killed it and where, and keeps its session", %{
    session: session,
    id: id
  } do
    Characters.mutate(session, &die/1)

    record = Repo.get!(Record, id)
    assert record.dead
    assert record.state["killer"] == "Wolf"
    assert record.state["fell_at"] == "obelisk-of-victory"
    assert record.session_id == session
    assert {^id, %Player{dead: true}} = Store.load_by_session(session)
  end

  test "the run stays the browser's, a ghost that wears nothing else and mends nothing", %{
    session: session,
    id: id
  } do
    {:ok, player} = Characters.mutate(session, &die/1)

    assert Characters.character_id(session) == id
    assert [%{id: "ghost"}] = Player.auras(player)
    assert Player.regenerate(player) == {player, false}
    assert Player.engage(player) == player
  end

  test "and does nothing", %{session: session} do
    {:ok, player} = Characters.mutate(session, &die/1)
    [entry | _] = player.items

    for action <- [
          &Actions.hunt/1,
          &Actions.retreat/1,
          &Actions.travel(&1, "town-of-gludio"),
          &Actions.buy(&1, "Healing Potion"),
          &Actions.sell(&1, entry.id),
          &Actions.equip(&1, entry.id),
          &Actions.unequip(&1, entry.id),
          &Actions.drink(&1, entry.id),
          &Actions.destroy(&1, entry.id),
          &Actions.learn(&1, "Power Strike", 2),
          &Actions.potion_at(&1, 30),
          &Actions.heal_at(&1, :pull, 30),
          &Actions.use_skill(&1, "Power Strike", false),
          &Actions.reset_orders/1,
          &Actions.dev_adena/1,
          &Actions.dev_sp/1,
          &Actions.dev_half/1,
          &Actions.dev_frail/1,
          &Actions.dev_level/1,
          &Actions.dev_max_level/1
        ] do
      assert {^player, {:error, :fallen, _}} = action.(player)
    end
  end

  test "only a run that has ended begins again", %{session: session} do
    assert {{:error, :living, _}, %Player{race_id: 0}} =
             Characters.mutate(session, &Actions.restart/1)
  end

  describe "beginning again" do
    setup %{session: session} do
      Characters.mutate(session, &die/1)
      :ok
    end

    test "gives up the session and keeps the row", %{session: session, id: id} do
      Characters.mutate(session, &Actions.restart/1)

      record = Repo.get!(Record, id)
      assert record.dead
      assert record.session_id == nil
      assert Store.load_by_session(session) == nil
    end

    test "and the browser goes on as a visitor, under a new id", %{session: session, id: id} do
      {{:ok, _}, player} = Characters.mutate(session, &Actions.restart/1)

      assert player == %Player{}
      assert Characters.snapshot(session) == %Player{}
      refute Characters.character_id(session) == id
    end

    test "another tab is told, and follows", %{session: session} do
      Characters.subscribe(session)
      Characters.mutate(session, &Actions.restart/1)

      assert_receive {:character_updated, %Player{race_id: nil}}
    end
  end
end
