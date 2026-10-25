defmodule MiniLineageWeb.HallsTest do
  @moduledoc """
  The Halls in the browser's own terms: every state may read them, overall or by lineage, the
  reader's own run is marked, a run that ended stays with its fate, and no session reaches the page.
  """
  use MiniLineageWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Ecto.Query

  alias MiniLineage.{Characters, Repo}
  alias MiniLineage.Characters.{Record, Store}
  alias MiniLineage.Game.{Clock, Constants, Player}

  # A zone whose day differs from UTC's, so a fall's day is shown to be the game's.
  setup do
    Repo.delete_all(Record)
    MiniLineage.Zone.put("Europe/Bucharest")
  end

  # A character played through the page, as a browser would.
  defp play(conn, name, race_id) do
    session = Characters.new_session_id()
    on_exit(fn -> Characters.forget(session) end)
    conn = init_test_session(conn, %{"session_id" => session})
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> element("form[phx-submit=start]")
    |> render_submit(%{"name" => name, "race_id" => "#{race_id}", "path" => "fighter"})

    {conn, session}
  end

  # Fallen at 10:30 pm UTC on 23 Oct 2026, which is already the 24th in the game's zone.
  defp fallen(name, at \\ ~U[2026-10-23 22:30:00Z]) do
    {player, _} = Player.initialize(%Player{}, Constants.race(1), :fighter, name)
    id = Store.new_id()
    died_at = DateTime.to_unix(at, :millisecond)

    Store.retire(id, %{
      player
      | experience: 900,
        dead: true,
        killer: "Kasha Wolf",
        died_at: died_at
    })

    id
  end

  test "a visitor may read them, and finds them silent before anyone has played" do
    {:ok, view, _html} = live(build_conn(), ~p"/monument-of-heroes")

    assert has_element?(view, "#screen[data-screen=highscores]")
    assert has_element?(view, "#halls-empty")
  end

  test "a character's own run is marked, and a fallen one keeps its place" do
    {conn, session} = play(build_conn(), "Wanderer", 2)
    id = fallen("Gone")
    recent = fallen("Lately", ~U[2026-11-09 23:57:00Z])
    mine = Characters.character_id(session)

    # Past the week a stamp ages for, and three minutes after the latest fall.
    Clock.put_now(~U[2026-11-10 00:00:00Z])
    {:ok, view, html} = live(conn, ~p"/monument-of-heroes")

    assert has_element?(view, "#row-#{mine}.mine[data-fate=living]")
    assert has_element?(view, "#row-#{id}[data-fate=fallen]")
    refute html =~ session

    # How long ago it fell, then past a week the day, in the game's zone; none for a run still
    # standing. The date says it, so no skull does.
    assert has_element?(view, ~s(#fell-#{recent}[phx-hook=Stamp][data-age-ms="180000"]), "3m ago")

    assert has_element?(
             view,
             ~s(#fell-#{id}.date[datetime="2026-10-23T22:30:00.000000Z"][title="24 Oct 2026, 1:30 am EEST"]),
             "24 Oct"
           )

    refute has_element?(view, "#row-#{mine} time")
    refute html =~ "💀"

    # Each cell names its fate, so a run still standing reads apart from one that ended.
    assert has_element?(view, "#fate-#{mine}", "Alive")
    assert has_element?(view, "#fate-#{id}", "Fell")
  end

  test "a character reaches them from the last of its town's Travel, and still stands in that town" do
    {conn, session} = play(build_conn(), "Wanderer", 2)
    {:ok, view, _html} = live(conn, ~p"/elven-village")

    assert has_element?(
             view,
             ~s(#travel-form option:last-child[value="highscores"]),
             "🏛️ Monument of Heroes"
           )

    view |> form("#travel-form", %{"place" => "highscores"}) |> render_submit()

    assert_patch(view, ~p"/monument-of-heroes")
    assert has_element?(view, "#screen[data-screen=highscores]")
    assert has_element?(view, "#row-#{Characters.character_id(session)}.mine")

    assert {:error, {:live_redirect, %{to: "/elven-village"}}} = live(conn, ~p"/")
  end

  test "a lineage's board is its own address, and holds only its own" do
    {conn, session} = play(build_conn(), "Wanderer", 2)
    id = fallen("Gone")
    mine = Characters.character_id(session)

    {:ok, view, _html} = live(conn, ~p"/monument-of-heroes/elves")

    assert has_element?(view, "#row-#{mine}")
    refute has_element?(view, "#row-#{id}")
    assert has_element?(view, ~s(a.btn.active[href="/monument-of-heroes/elves"]))
  end

  test "a run that went missing is neither living nor fallen, and says when it was last seen" do
    {player, _} = Player.initialize(%Player{}, Constants.race(0), :fighter, "Drifter")
    id = Store.new_id()
    Store.save(id, Characters.new_session_id(), player, false)

    # Retired as the sweep would, its last sighting the later of its last write and last look.
    Repo.update_all(from(r in Record, where: r.id == ^id),
      set: [
        session_id: nil,
        updated_at: ~U[2026-09-17 10:00:00.000000Z],
        seen_at: ~U[2026-09-20 10:00:00.000000Z]
      ]
    )

    Clock.put_now(~U[2026-11-10 00:00:00Z])
    {:ok, view, _html} = live(build_conn(), ~p"/monument-of-heroes")

    assert has_element?(view, "#row-#{id}[data-fate=missing]")
    assert has_element?(view, "#fate-#{id}", "Vanished")

    assert has_element?(
             view,
             ~s(#missing-#{id}.date[datetime="2026-09-20T10:00:00.000000Z"]),
             "20 Sep"
           )

    refute has_element?(view, "#fell-#{id}")
  end
end
