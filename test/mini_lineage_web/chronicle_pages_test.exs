defmodule MiniLineageWeb.ChroniclePagesTest do
  @moduledoc """
  A long Chronicle as a page: it opens on its newest twenty-five entries, newest first, and hands
  over the twenty-five before the last it holds each time the hook asks. The scrolling that asks
  is the browser's, driven by `live-board.mjs`; this is what the ask gets back.
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

  # What the watched run writes next, as its process would announce it.
  defp write(view, id, n) do
    at = DateTime.utc_now()

    Repo.insert_all(CharacterLog.Entry, [
      CharacterLog.params(CharacterLog.event(id, "purchase", "Deed #{n}.", at))
    ])

    {player, _} = Player.initialize(%Player{}, Constants.race(1), "Longlived")
    send(view.pid, {:record_updated, player, id, true})
    render(view)
  end

  # Asked by the name the page gives its hook, so the two cannot drift apart.
  defp at_present(view, html, at) do
    [event] =
      html
      |> LazyHTML.from_document()
      |> LazyHTML.query("#chronicle")
      |> LazyHTML.attribute("data-at-present")

    render_hook(view, event, %{"at" => at})
  end

  # Newest first, so what is written while it is read goes on top, and nothing already held moves.
  test "puts an entry written while it is read on top of the rest", %{conn: conn} do
    id = run_with(30)
    {:ok, view, html} = live(conn, ~p"/character/#{id}")
    held = lines(html)
    at_present(view, html, false)

    html = write(view, id, 31)
    assert lines(html) == ["Deed 31." | held]
    assert Enum.take(numbers(html), 2) == ["#31", "#30"]
  end

  # A watch on a long fight would otherwise hold every entry it was shown, in the page and here
  # both, and letting a batch go at once jumps the scrollbar.
  describe "a reader at the present" do
    test "lets the oldest go as the newest lands, holding one height", %{conn: conn} do
      id = run_with(30)
      {:ok, view, _html} = live(conn, ~p"/character/#{id}")

      html = write(view, id, 31)
      assert lines(html) == Enum.map(31..7//-1, &"Deed #{&1}.")

      html = render_hook(view, "older_chronicle", %{"before" => older_than(html)})
      assert lines(html) == Enum.map(31..1//-1, &"Deed #{&1}.")
    end

    test "and holds what it had loaded, rather than cutting back to a page", %{conn: conn} do
      id = run_with(60)
      {:ok, view, html} = live(conn, ~p"/character/#{id}")
      render_hook(view, "older_chronicle", %{"before" => older_than(html)})

      html = write(view, id, 61)
      assert lines(html) == Enum.map(61..12//-1, &"Deed #{&1}.")
    end

    test "while a run shorter than a page grows to one", %{conn: conn} do
      id = run_with(3)
      {:ok, view, _html} = live(conn, ~p"/character/#{id}")

      html = write(view, id, 4)
      assert lines(html) == Enum.map(4..1//-1, &"Deed #{&1}.")
      refute older_than(html)
    end

    test "and one who comes back to it holds steady from there", %{conn: conn} do
      id = run_with(30)
      {:ok, view, html} = live(conn, ~p"/character/#{id}")
      at_present(view, html, false)
      html = write(view, id, 31)
      at_present(view, html, true)

      html = write(view, id, 32)
      assert lines(html) == Enum.map(32..7//-1, &"Deed #{&1}.")
    end
  end

  test "and a run that fits on one page never offers another", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/character/#{run_with(25)}")

    assert length(lines(html)) == 25
    refute older_than(html)
  end
end
