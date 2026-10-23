defmodule MiniLineage.Characters.EncountersTest do
  @moduledoc """
  Rules §20 where it is kept: every fight a run fights is written to `encounters` in the
  character's own transaction, and a ground reads back the last one fought on it, as the hunt told
  it, so a reload draws the page the click drew.
  """
  use MiniLineage.DataCase, async: false

  alias MiniLineage.Characters
  alias MiniLineage.Characters.{Encounter, Store}
  alias MiniLineage.Game.{Actions, Rng}

  @ground "obelisk-of-victory"

  setup do
    session = Characters.new_session_id()
    on_exit(fn -> Characters.forget(session) end)
    Characters.mutate(session, &Actions.start(&1, 0, "fighter", "Fought"))

    # Every roll landing for both sides, so no fight here can end the run before the next.
    Characters.mutate(session, fn player ->
      Rng.put_source(fn -> 0.0 end)
      {player, :ok}
    end)

    %{session: session, id: Characters.character_id(session)}
  end

  defp fights(id),
    do: Repo.all(from e in Encounter, where: e.character_id == ^id, select: e.ground)

  defp hunt(session) do
    {{:ok, flash}, _player} = Characters.mutate(session, &Actions.hunt/1)
    flash
  end

  test "a hunt writes one fight under its ground, and the ground reads it back", %{
    session: session,
    id: id
  } do
    flash = hunt(session)

    assert fights(id) == [@ground]
    fight = Characters.last_fight(session, @ground)
    assert Map.take(fight, [:log, :text, :outcome]) == Map.take(flash, [:log, :text, :outcome])
    assert Characters.last_fight(session, "elven-fortress") == nil
  end

  test "the last fight is the one read", %{session: session, id: id} do
    hunt(session)
    Characters.mutate(session, &{%{&1 | health: 100}, :ok})
    last = hunt(session)

    assert length(fights(id)) == 2
    assert Characters.last_fight(session, @ground).log == last.log
  end

  test "nothing but a fight writes one", %{session: session, id: id} do
    Characters.mutate(session, &Actions.potion_at(&1, 30))
    Characters.mutate(session, &Actions.retreat/1)

    assert fights(id) == []
  end

  test "and a character deleted takes its fights with it", %{session: session, id: id} do
    hunt(session)
    Store.delete(id)

    assert fights(id) == []
  end
end
