defmodule MiniLineageWeb.ChroniclePagesTest do
  @moduledoc """
  A long Chronicle as a page: it opens on its newest twenty-five entries, newest first, and hands
  over the twenty-five before the last it holds each time the reader's hook asks, until there are none left.

  The scrolling that asks is the browser's, and `live-board.mjs` drives it; this is what the ask
  gets back.
  """
  use MiniLineageWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias MiniLineage.{CharacterLog, Characters, Repo}
  alias MiniLineage.Characters.Store
  alias MiniLineage.Game.{Constants, Player}

  # A run with `count` deeds and nothing else, written straight into the table: no dice, and no
  # blessing or beginning of its own to throw the count.
  defp run_with(count) do
    id = Store.new_id()
    {player, _} = Player.initialize(%Player{}, Constants.race(1), "Longlived")
    :ok = Store.save(id, Characters.new_session_id(), player)
    Repo.query!("DELETE FROM character_log WHERE character_id = $1", [id])

    at = DateTime.utc_now()

    rows =
      for n <- 1..count,
          do: CharacterLog.params(CharacterLog.event(id, "purchase", "Deed #{n}.", at))

    Repo.insert_all(CharacterLog.Entry, rows)
    id
  end

  defp held(html), do: html |> LazyHTML.from_document() |> LazyHTML.query("#chronicle-log li")

  defp lines(html), do: texts(html, "#chronicle-log > li > span")

  defp numbers(html), do: texts(html, "#chronicle-log .entry-head > span:last-child")

  defp texts(html, selector),
    do: html |> LazyHTML.from_document() |> LazyHTML.query(selector) |> Enum.map(&LazyHTML.text/1)

  defp older_than(html) do
    case html
         |> LazyHTML.from_document()
         |> LazyHTML.query("#chronicle-log")
         |> LazyHTML.attribute("data-older-than") do
      [before] -> String.to_integer(before)
      [] -> nil
    end
  end

  test "opens on the newest twenty-five, newest first, and says there are more", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/character/#{run_with(120)}")

    assert lines(html) == Enum.map(120..96//-1, &"Deed #{&1}.")
    assert older_than(html)
  end

  test "hands over the twenty-five before, and so on to the first, then stops asking", %{
    conn: conn
  } do
    {:ok, view, html} = live(conn, ~p"/character/#{run_with(120)}")

    html = render_hook(view, "older_chronicle", %{"before" => older_than(html)})
    assert lines(html) == Enum.map(120..71//-1, &"Deed #{&1}.")

    html =
      Enum.reduce(1..3, html, fn _, html ->
        render_hook(view, "older_chronicle", %{"before" => older_than(html)})
      end)

    assert lines(html) == Enum.map(120..1//-1, &"Deed #{&1}.")
    refute older_than(html)
  end

  # Counted rather than stored, so every page has to count from the right place: the first row of
  # the run is #1 however many pages it took to reach it.
  test "numbers every entry by its place in the run, from the newest page to the first", %{
    conn: conn
  } do
    {:ok, view, html} = live(conn, ~p"/character/#{run_with(120)}")
    assert numbers(html) == Enum.map(120..96//-1, &"##{&1}")

    html =
      Enum.reduce(1..4, html, fn _, html ->
        render_hook(view, "older_chronicle", %{"before" => older_than(html)})
      end)

    assert numbers(html) == Enum.map(120..1//-1, &"##{&1}")
  end

  # Two scroll events can both ask before the first answer lands; the second names an entry that is
  # no longer the last held, and must not put the same page on the end a second time.
  test "and an ask that is already answered changes nothing", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/character/#{run_with(120)}")
    before = older_than(html)

    render_hook(view, "older_chronicle", %{"before" => before})
    html = render_hook(view, "older_chronicle", %{"before" => before})

    assert length(held(html) |> Enum.to_list()) == 50
  end

  # Newest first, so what is written while it is read goes on top, and nothing already held moves.
  test "puts an entry written while it is read on top of the rest", %{conn: conn} do
    id = run_with(30)
    {:ok, view, html} = live(conn, ~p"/character/#{id}")
    held = lines(html)

    at = DateTime.utc_now()

    Repo.insert_all(CharacterLog.Entry, [
      CharacterLog.params(CharacterLog.event(id, "purchase", "Deed 31.", at))
    ])

    {player, _} = Player.initialize(%Player{}, Constants.race(1), "Longlived")
    send(view.pid, {:record_updated, player, id, true})

    html = render(view)
    assert lines(html) == ["Deed 31." | held]
    assert Enum.take(numbers(html), 2) == ["#31", "#30"]
  end

  test "and a run that fits on one page never offers another", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/character/#{run_with(25)}")

    assert length(lines(html)) == 25
    refute older_than(html)
  end
end
