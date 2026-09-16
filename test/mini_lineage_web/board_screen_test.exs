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
    test "lists a living run, and links its NAME to its own page", %{conn: conn} do
      %{id: id} = run("Walker", xp: 500)

      {:ok, _live, html} = live(conn, ~p"/highscores")
      [_, linked] = Regex.run(~r|<a[^>]*href="/character/#{id}"[^>]*>(.*?)</a>|s, html)

      # Only the name. The emoji around it are decoration, and a race badge is not navigation.
      assert String.trim(linked) == "Walker"
    end

    test "says the halls are silent rather than drawing an empty table", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/highscores")

      assert html =~ "The Hall is silent"
      refute html =~ "data-table"
    end

    test "leaves a disqualified run off it", %{conn: conn} do
      run("Honest", xp: 10)
      run("Coward", xp: 9_000, dead: true, coward: true)

      {:ok, _live, html} = live(conn, ~p"/highscores")

      assert html =~ "Honest"
      refute html =~ "Coward"
    end

    test "hands the first three a medal, and nobody else", %{conn: conn} do
      for {name, xp} <- [{"Gold", 900}, {"Silver", 800}, {"Bronze", 700}, {"Fourth", 600}] do
        run(name, xp: xp)
      end

      {:ok, _live, html} = live(conn, ~p"/highscores")
      row = fn name -> Enum.find(String.split(html, "<tr"), &String.contains?(&1, name)) end

      assert row.("Gold") =~ "🥇"
      assert row.("Silver") =~ "🥈"
      assert row.("Bronze") =~ "🥉"
      refute row.("Fourth") =~ "🥇"
      refute row.("Fourth") =~ "🥈"
      refute row.("Fourth") =~ "🥉"
    end

    test "and carries no rank column, as it never did", %{conn: conn} do
      run("Alone", xp: 10)

      {:ok, _live, html} = live(conn, ~p"/highscores")
      headers = Regex.scan(~r/<th[^>]*>\s*([^<]*?)\s*<\/th>/, html) |> Enum.map(&List.last/1)

      assert headers == ["Name", "Level", "Total XP", "Wealth", "Date"]
    end

    test "marks a run still being played, and leaves a finished one plain", %{conn: conn} do
      run("Alive", xp: 500)
      run("Fallen", xp: 400, dead: true)

      {:ok, _live, html} = live(conn, ~p"/highscores")
      row = fn name -> Enum.find(String.split(html, "<tr"), &String.contains?(&1, name)) end

      assert row.("Alive") =~ "alive"
      refute row.("Fallen") =~ "alive"
      refute html =~ "⚔️", "the sword was replaced by the row itself"
    end

    test "leaves a retired run plain, however it stopped", %{conn: conn} do
      %{session: session} = run("Missing", xp: 500)
      MiniLineage.Characters.archive(session)
      on_exit(fn -> MiniLineage.Characters.forget(session) end)
      run("Going", xp: 400)

      {:ok, _live, html} = live(conn, ~p"/highscores")
      row = fn name -> Enum.find(String.split(html, "<tr"), &String.contains?(&1, name)) end

      assert row.("Going") =~ "alive"
      refute row.("Missing") =~ "alive", "a run nobody can pick up again is not still going"
    end

    test "tells a stranger's story in the third person, not the reader's", %{conn: conn} do
      %{id: id} = run("Aurelia", xp: 500)

      {:ok, _live, html} = live(conn, ~p"/character/#{id}")

      # They/them, because the game records no gender — and because it takes the same verb forms
      # as "you", so only the pronouns move between the two pages.
      assert html =~ "Their journey across the realm"
      assert html =~ "They are wielding"
      refute html =~ "You are wielding"
      refute html =~ "Your journey"
      # The heading names them; the prose never does.
      assert html =~ "Aurelia of"
    end

    test "sends you back where you came from, as a link and not a button", %{conn: conn} do
      %{id: id} = run("Aurelia", xp: 500)

      {:ok, _live, halls} = live(conn, ~p"/character/#{id}")
      assert halls =~ "Go back to the Hall of All Champions"
      refute halls =~ "btn btn-secondary", "the way out of a record has never been an action"

      {:ok, _live, game} = live(conn, ~p"/character/#{id}?from=game")
      refute game =~ "Go back to the Hall of"
    end

    test "keeps the lineage you were reading, all the way there and back", %{conn: conn} do
      %{id: id} = run("Shadowy", race_id: 3, xp: 500)

      {:ok, _live, board} = live(conn, ~p"/highscores/dark-elf")
      assert board =~ ~s(href="/character/#{id}?from=dark-elf")

      {:ok, _live, record} = live(conn, ~p"/character/#{id}?from=dark-elf")
      assert record =~ ~s(href="/highscores/dark-elf")
    end

    test "and the link says the hall it goes to", %{conn: conn} do
      %{id: id} = run("Shadowy", race_id: 3, xp: 500)

      {:ok, _live, filtered} = live(conn, ~p"/character/#{id}?from=dark-elf")
      assert filtered =~ "Go back to the Hall of Dark Elf Champions"

      {:ok, _live, all} = live(conn, ~p"/character/#{id}")
      assert all =~ "Go back to the Hall of All Champions"
    end

    test "and the unfiltered Halls send you back unfiltered", %{conn: conn} do
      %{id: id} = run("Shadowy", race_id: 3, xp: 500)

      {:ok, _live, board} = live(conn, ~p"/highscores")
      assert board =~ ~s(href="/character/#{id}")
      refute board =~ "from="

      {:ok, _live, record} = live(conn, ~p"/character/#{id}")
      assert record =~ ~s(href="/highscores")
    end

    test "and a lineage the game has never heard of decides nothing", %{conn: conn} do
      %{id: id} = run("Shadowy", race_id: 3, xp: 500)

      # `from` arrives in the URL, so it is looked up rather than trusted.
      {:ok, _live, html} = live(conn, ~p"/character/#{id}?from=../../etc")

      assert html =~ ~s(href="/highscores")
      refute html =~ "etc"
    end

    test "and carries the full record, not a summary", %{conn: conn} do
      %{id: id} = run("Aurelia", xp: 500)

      {:ok, _live, html} = live(conn, ~p"/character/#{id}")

      # The same sections your own page has: ancestry, stats, the journey, then the chronicle.
      assert html =~ "Inventory &amp; Stats"
      assert html =~ "Physical Attack"
      assert html =~ "Ambush Risk"
      assert html =~ "The Chronicle"
    end

    test "and a missing run's page says so rather than claiming it fell", %{conn: conn} do
      %{id: id, session: session} = run("Missing", xp: 500)
      MiniLineage.Characters.archive(session)
      on_exit(fn -> MiniLineage.Characters.forget(session) end)

      {:ok, _live, html} = live(conn, ~p"/character/#{id}")

      assert html =~ "has not been seen since"
      refute html =~ "and fell on"
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

      {:ok, _live, html} = live(conn, ~p"/character/#{id}")

      assert html =~ "Remembered"
      assert html =~ "and fell on"
    end

    test "still renders a disqualified one, with the reason stated", %{conn: conn} do
      %{id: id} = run("Coward", xp: 50, dead: true, coward: true)

      {:ok, _live, html} = live(conn, ~p"/character/#{id}")

      assert html =~ "Coward"
      assert html =~ "Barred from the Hall of Champions"
    end

    test "and says so plainly for an id that is nobody", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/character/not-a-real-id")

      assert html =~ "No such name is written here"
    end

    test "viewing one does not make the viewer that character", %{conn: conn} do
      %{id: id} = run("Someone", xp: 500, dead: true)

      {:ok, live, _html} = live(conn, ~p"/character/#{id}")

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
