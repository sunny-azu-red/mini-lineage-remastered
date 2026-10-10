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
  alias MiniLineage.Game.{Constants, Player}

  setup do
    Repo.delete_all(Record)
    :ok
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

  defp fallen(name) do
    {player, _} = Player.initialize(%Player{}, Constants.race(1), :fighter, name)
    id = Store.new_id()
    Store.retire(id, %{player | experience: 900, dead: true, killer: "Kasha Wolf"})
    id
  end

  test "a visitor may read them, and finds them silent before anyone has played" do
    {:ok, view, _html} = live(build_conn(), ~p"/highscores")

    assert has_element?(view, "#screen[data-screen=highscores]")
    assert has_element?(view, "#halls-empty")
  end

  test "a character's own run is marked, and a fallen one keeps its place" do
    {conn, session} = play(build_conn(), "Wanderer", 2)
    id = fallen("Gone")
    mine = Characters.character_id(session)

    {:ok, view, html} = live(conn, ~p"/highscores")

    assert has_element?(view, "#row-#{mine}.mine[data-fate=living]")
    assert has_element?(view, "#row-#{id}[data-fate=fallen]")
    refute html =~ session
  end

  test "a lineage's board is its own address, and holds only its own" do
    {conn, session} = play(build_conn(), "Wanderer", 2)
    id = fallen("Gone")
    mine = Characters.character_id(session)

    {:ok, view, _html} = live(conn, ~p"/highscores/elf")

    assert has_element?(view, "#row-#{mine}")
    refute has_element?(view, "#row-#{id}")
    assert has_element?(view, ~s(a.btn.active[href="/highscores/elf"]))
  end

  test "a run that went missing is neither living nor fallen" do
    {_conn, session} = play(build_conn(), "Wanderer", 0)
    id = Characters.character_id(session)
    Repo.update_all(from(r in Record, where: r.id == ^id), set: [session_id: nil])

    {:ok, view, _html} = live(build_conn(), ~p"/highscores")

    assert has_element?(view, "#row-#{id}[data-fate=missing]")
  end
end
