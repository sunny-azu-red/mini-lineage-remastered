defmodule MiniLineageWeb.BoardScreenTest do
  @moduledoc """
  The Halls of Champions as a page: what it renders, and that a push actually changes it.

  The live board is the point of the redesign, and a process that computes a correct ranking
  nobody ever sees would pass every test in `BoardTest`. This is the other half — the LiveView
  receiving that push and re-rendering it.
  """
  use MiniLineageWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias MiniLineage.{Board, Characters, Repo}
  alias MiniLineage.Characters.Store
  alias MiniLineage.Game.{Constants, Player}

  setup do
    Repo.query!("DELETE FROM battle_log")
    Repo.query!("DELETE FROM characters")

    :ok
  end

  defp run(name, opts) do
    session = Characters.new_session_id()
    id = Store.new_id()
    {player, _} = Player.initialize(%Player{}, Constants.race(opts[:race_id] || 0), name)

    :ok =
      Store.save(id, session, %{
        player
        | experience: opts[:xp] || 0,
          adena: opts[:adena] || 0,
          dead: opts[:dead] || false,
          coward: opts[:coward] || false
      })

    %{id: id, session: session}
  end

  describe "the board" do
    test "lists a living run, and links it to its own page", %{conn: conn} do
      %{id: id} = run("Walker", xp: 500)

      {:ok, _live, html} = live(conn, ~p"/highscores")

      assert html =~ "Walker"
      assert html =~ ~s(href="/champion/#{id}")
    end

    test "says the halls are silent rather than drawing an empty table", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/highscores")

      assert html =~ "The halls are silent"
      refute html =~ "data-table"
    end

    test "leaves a disqualified run off it", %{conn: conn} do
      run("Honest", xp: 10)
      run("Coward", xp: 9_000, dead: true, coward: true)

      {:ok, _live, html} = live(conn, ~p"/highscores")

      assert html =~ "Honest"
      refute html =~ "Coward"
    end

    test "and never renders a session id anywhere on the page", %{conn: conn} do
      %{session: session} = run("Named", xp: 10)

      {:ok, _live, html} = live(conn, ~p"/highscores")

      refute html =~ session
    end
  end

  describe "a push" do
    setup do
      pid = start_supervised!(MiniLineage.Board)
      Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)

      :ok
    end

    test "changes the page without the viewer asking for it", %{conn: conn} do
      {:ok, live, html} = live(conn, ~p"/highscores")
      refute html =~ "Latecomer"

      # Somebody else, on another connection entirely, plays. Nothing this viewer does asks for the
      # new board — the push is the whole mechanism under test.
      run("Latecomer", xp: 9_000)
      Board.character_changed()

      assert wait_for(live, "Latecomer"), "the board did not update itself"
    end

    test "and a viewer who mounts after the refresh sees it straight away", %{conn: conn} do
      # `current/0` answers from the cache, so this is what a second viewer arriving later gets.
      run("Settled", xp: 10)
      Board.character_changed()
      Process.sleep(700)

      {:ok, _live, html} = live(conn, ~p"/highscores")

      assert html =~ "Settled"
    end
  end

  describe "a champion's page" do
    test "renders a run by its public id", %{conn: conn} do
      %{id: id} = run("Remembered", xp: 1_234, adena: 99, dead: true)

      {:ok, _live, html} = live(conn, ~p"/champion/#{id}")

      assert html =~ "Remembered"
      assert html =~ "road ended"
    end

    test "still renders a disqualified one, with the reason stated", %{conn: conn} do
      %{id: id} = run("Coward", xp: 50, dead: true, coward: true)

      {:ok, _live, html} = live(conn, ~p"/champion/#{id}")

      assert html =~ "Coward"
      assert html =~ "Barred from the Halls"
    end

    test "and says so plainly for an id that is nobody", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/champion/not-a-real-id")

      assert html =~ "No such name is written here"
    end

    test "viewing one does not make the viewer that character", %{conn: conn} do
      %{id: id} = run("Someone", xp: 500, dead: true)

      {:ok, live, _html} = live(conn, ~p"/champion/#{id}")

      # The strongest form: a visitor reading a champion's page is still a visitor, and going home
      # puts them at Game Start rather than into somebody else's run.
      assert render(live) =~ "Someone"
      {:ok, _home, home_html} = live(conn, ~p"/")
      refute home_html =~ "Someone"
    end
  end

  # LiveView has no "wait for a pushed re-render" helper, so this polls the rendered markup.
  defp wait_for(live, text, attempts \\ 20) do
    cond do
      render(live) =~ text -> true
      attempts == 0 -> false
      true -> Process.sleep(50) && wait_for(live, text, attempts - 1)
    end
  end
end
