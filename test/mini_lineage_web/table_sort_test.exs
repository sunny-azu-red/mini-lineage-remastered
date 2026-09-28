defmodule MiniLineageWeb.TableSortTest do
  @moduledoc """
  A table sorted by its header: the Halls, which sort, and the shops, which do not. The rows are
  ordered by the server from what the socket already holds, so every assertion reads the rendered
  order rather than anything the browser would do to it.
  """
  use MiniLineageWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias MiniLineage.{Characters, Repo}
  alias MiniLineage.Characters.Store
  alias MiniLineage.Game.{Constants, Math, Player, Snapshot}
  alias MiniLineageWeb.Controls

  setup do
    Repo.query!("DELETE FROM character_log")
    Repo.query!("DELETE FROM characters")

    :ok
  end

  # No log entries, so a run was last seen when it was born, and `seen` says when that was.
  defp run(name, opts) do
    id = Store.new_id()
    {player, _} = Player.initialize(%Player{}, Constants.race(opts[:race_id] || 0), name)

    :ok =
      Store.save(id, Characters.new_session_id(), %{
        player
        | experience: opts[:xp] || 0,
          adena: opts[:adena] || 0
      })

    seen = DateTime.add(~U[2026-09-01 12:00:00.000000Z], opts[:seen] || 0, :minute)
    Repo.query!("UPDATE characters SET inserted_at = $1 WHERE id = $2", [seen, id])

    id
  end

  defp names(view) do
    view
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query("#halls-rows td.name a")
    |> Enum.map(&LazyHTML.text/1)
  end

  defp sorted(view) do
    view
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query("#halls-table th[aria-sort]")
    |> Enum.map(&{String.trim(LazyHTML.text(&1)), LazyHTML.attribute(&1, "aria-sort") |> hd()})
  end

  defp click(view, key),
    do: view |> element("#halls-table button[phx-value-key=#{key}]") |> render_click()

  # Ranked Gold, Silver, Bronze; seen Bronze, then Gold, then Silver, most recent first.
  defp three do
    run("gold", xp: 900, seen: 20)
    run("Silver", xp: 500, seen: 10)
    run("bronze", xp: 100, seen: 30)
  end

  describe "the Halls" do
    test "open on the ranking, with no header sorted and nothing to reset", %{conn: conn} do
      three()
      {:ok, view, _html} = live(conn, ~p"/highscores")

      assert names(view) == ["gold", "Silver", "bronze"]
      assert sorted(view) == []
      refute has_element?(view, "#halls-table-reset")
    end

    test "sort by Date newest first, then oldest, then return to the ranking", %{conn: conn} do
      three()
      {:ok, view, _html} = live(conn, ~p"/highscores")

      click(view, "date")
      assert names(view) == ["bronze", "gold", "Silver"]
      assert sorted(view) == [{"Date", "descending"}]
      assert has_element?(view, "#halls-table-reset")

      click(view, "date")
      assert names(view) == ["Silver", "gold", "bronze"]
      assert sorted(view) == [{"Date", "ascending"}]

      click(view, "date")
      assert names(view) == ["gold", "Silver", "bronze"]
      assert sorted(view) == []
      refute has_element?(view, "#halls-table-reset")
    end

    test "start another header over in its own first direction", %{conn: conn} do
      three()
      {:ok, view, _html} = live(conn, ~p"/highscores")

      click(view, "date")
      click(view, "name")

      assert names(view) == ["bronze", "gold", "Silver"], "A to Z, whatever the case"
      assert sorted(view) == [{"Name", "ascending"}]
    end

    test "reverse a name to Z first, and a figure to lowest first", %{conn: conn} do
      three()
      {:ok, view, _html} = live(conn, ~p"/highscores")

      click(view, "name")
      click(view, "name")
      assert names(view) == ["Silver", "gold", "bronze"]
      assert sorted(view) == [{"Name", "descending"}]

      click(view, "xp")
      click(view, "xp")
      assert names(view) == ["bronze", "Silver", "gold"]
      assert sorted(view) == [{"Total XP", "ascending"}]
    end

    test "keep rows equal on the column in the order they are ranked", %{conn: conn} do
      run("Third", xp: 100)
      run("First", xp: 500)
      run("Second", xp: 400)
      assert Math.level_for_xp(100) == Math.level_for_xp(500)
      {:ok, view, _html} = live(conn, ~p"/highscores")

      click(view, "level")
      assert names(view) == ["First", "Second", "Third"]

      click(view, "level")
      assert names(view) == ["First", "Second", "Third"], "only the level reverses"
    end

    test "reset from the filter row, which then takes the button away", %{conn: conn} do
      three()
      {:ok, view, _html} = live(conn, ~p"/highscores")

      click(view, "wealth")
      assert has_element?(view, ".action-links #halls-table-reset")

      view |> element("#halls-table-reset") |> render_click()
      assert names(view) == ["gold", "Silver", "bronze"]
      assert sorted(view) == []
      refute has_element?(view, "#halls-table-reset")
    end

    test "keep a sort across a change of filter", %{conn: conn} do
      three()
      {:ok, view, _html} = live(conn, ~p"/highscores")
      click(view, "date")

      [race | _] = Snapshot.catalog().races
      view |> element(~s|.action-links a[href="/highscores/#{race.slug}"]|) |> render_click()

      assert names(view) == ["bronze", "gold", "Silver"]
    end

    test "open on the sort a reader kept, handed over as the socket connects", %{conn: conn} do
      three()
      conn = put_connect_params(conn, %{"tables" => %{"halls-table" => "date:asc"}})
      {:ok, view, _html} = live(conn, ~p"/highscores")

      assert names(view) == ["Silver", "gold", "bronze"]
      assert sorted(view) == [{"Date", "ascending"}]
    end

    test "treat anything kept that the table does not offer as no sort at all", %{conn: conn} do
      three()

      for kept <- [
            %{"halls-table" => "date:sideways"},
            %{"halls-table" => "rank:asc"},
            %{"halls-table" => "date"},
            %{"halls-table" => 7},
            %{"weapon-table" => "name:asc"},
            "halls-table"
          ] do
        conn = put_connect_params(conn, %{"tables" => kept})
        {:ok, view, _html} = live(conn, ~p"/highscores")

        assert names(view) == ["gold", "Silver", "bronze"], inspect(kept)
      end
    end

    test "ignore a click on a column or a table that does not sort", %{conn: conn} do
      three()
      {:ok, view, _html} = live(conn, ~p"/highscores")

      render_click(view, "sort", %{"table" => "halls-table", "key" => "id"})
      render_click(view, "sort", %{"table" => "weapon-table", "key" => "name"})

      assert names(view) == ["gold", "Silver", "bronze"]
      assert sorted(view) == []
    end
  end

  test "a click cycles first, other, none, and another column starts afresh" do
    assert Controls.next_sort(nil, "xp", :desc) == {"xp", :desc}
    assert Controls.next_sort({"xp", :desc}, "xp", :desc) == {"xp", :asc}
    assert Controls.next_sort({"xp", :asc}, "xp", :desc) == nil
    assert Controls.next_sort({"xp", :asc}, "name", :asc) == {"name", :asc}
  end

  test "the shops label their columns and offer nothing to click" do
    {player, _} = Player.initialize(%Player{}, Constants.race(0), "Buyer")

    doc =
      render_component(&MiniLineageWeb.Screens.screen/1,
        view: Snapshot.build(%{player | current_screen: "weapons"}),
        screen: "weapons",
        catalog: Snapshot.catalog()
      )
      |> LazyHTML.from_fragment()

    assert Enum.count(LazyHTML.query(doc, "#weapon-table th")) == 4
    assert Enum.empty?(LazyHTML.query(doc, "#weapon-table button, #weapon-table [phx-hook]"))
  end
end
