defmodule MiniLineageWeb.RecordFreshnessTest do
  @moduledoc """
  A stranger's record opens on what the run's process holds, not on the stored document.

  Where a run stands, the auras that follow from it and its health are buffered, so the row can be
  a minute behind: a visitor refreshing a run that walked home from a fight was shown it still In
  Combat until the next tick's push corrected it.
  """
  use MiniLineageWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias MiniLineage.Characters
  alias MiniLineage.Characters.Store
  alias MiniLineage.Game.{Actions, Constants, Player}

  setup do
    session = Characters.new_session_id()
    on_exit(fn -> Characters.forget(session) end)

    Characters.mutate(session, fn player ->
      {player, _flash} = Player.initialize(player, Constants.race(0), "Wanderer")
      {%{player | current_screen: "home"}, :ok}
    end)

    %{session: session, id: Characters.character_id(session)}
  end

  defp blessings(html) do
    [_, section] = Regex.run(~r|Blessings &amp; Afflictions</h2>(.*?)<h2|s, html)
    section
  end

  test "while the run's process is up, a visitor reads it rather than the row", %{
    conn: conn,
    session: session,
    id: id
  } do
    Characters.mutate(session, &Actions.set_screen(&1, "battle"))
    # The walk is buffered, so the row still has them resting at home.
    {^id, stored} = Store.load_by_session(session)
    assert stored.current_screen == "home"

    {:ok, _live, html} = live(conn, ~p"/character/#{id}")

    assert blessings(html) =~ "In Combat"
    refute blessings(html) =~ "Resting"
  end

  test "and with none up, the row is read and no process is started for it", %{
    conn: conn,
    session: session,
    id: id
  } do
    Characters.forget_process(session)

    {:ok, _live, html} = live(conn, ~p"/character/#{id}")

    assert blessings(html) =~ "Resting"
    assert Registry.lookup(MiniLineage.Characters.Registry, session) == []
  end
end
