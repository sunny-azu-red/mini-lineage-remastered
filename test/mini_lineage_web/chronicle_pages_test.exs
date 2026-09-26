defmodule MiniLineageWeb.ChroniclePagesTest do
  @moduledoc """
  A long Chronicle as a page: it opens on its newest fifty entries, and hands over the fifty
  before whichever it opens on each time the reader's hook asks, until there are none left.

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

  defp lines(html), do: html |> held() |> Enum.map(&LazyHTML.text/1) |> Enum.map(&deed/1)

  defp deed(text), do: text |> String.split("Purchase") |> List.last() |> String.trim()

  defp older_than(html) do
    case html
         |> LazyHTML.from_document()
         |> LazyHTML.query("#chronicle-log")
         |> LazyHTML.attribute("data-older-than") do
      [before] -> String.to_integer(before)
      [] -> nil
    end
  end

  test "opens on the newest fifty, and says there are more", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/character/#{run_with(120)}")

    assert lines(html) == Enum.map(71..120, &"Deed #{&1}.")
    assert older_than(html)
  end

  test "hands over the fifty before, then the rest, then stops asking", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/character/#{run_with(120)}")

    html = render_hook(view, "older_chronicle", %{"before" => older_than(html)})
    assert lines(html) == Enum.map(21..120, &"Deed #{&1}.")

    html = render_hook(view, "older_chronicle", %{"before" => older_than(html)})
    assert lines(html) == Enum.map(1..120, &"Deed #{&1}.")
    refute older_than(html)
  end

  # Two scroll events can both ask before the first answer lands; the second names an entry the
  # chronicle no longer opens on, and must not put the same page in front a second time.
  test "and an ask that is already answered changes nothing", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/character/#{run_with(120)}")
    before = older_than(html)

    render_hook(view, "older_chronicle", %{"before" => before})
    html = render_hook(view, "older_chronicle", %{"before" => before})

    assert length(held(html) |> Enum.to_list()) == 100
  end

  test "and a run that fits on one page never offers another", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/character/#{run_with(50)}")

    assert length(lines(html)) == 50
    refute older_than(html)
  end
end
