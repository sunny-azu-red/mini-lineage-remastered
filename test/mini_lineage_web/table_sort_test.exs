defmodule MiniLineageWeb.TableSortTest do
  @moduledoc """
  Every table in the game sorts: each opens on its default, every header it lists is a button, and
  a click turns the sorted column round or starts another ascending.
  """
  use MiniLineageWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias MiniLineage.Characters
  alias MiniLineageWeb.{Controls, Screens}

  # A Human Fighter on Talking Island who has bought a Short Sword, so Sell has a row.
  setup do
    session = Characters.new_session_id()
    on_exit(fn -> Characters.forget(session) end)
    conn = init_test_session(build_conn(), %{"session_id" => session})
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> element("form[phx-submit=start]")
    |> render_submit(%{"name" => "Sorter", "race_id" => "0", "path" => "fighter"})

    Characters.mutate(session, &{%{&1 | adena: 10_000}, :ok})
    {:ok, view, _html} = live(conn, ~p"/talking-island/trader/weapons")
    render_hook(view, "buy", %{"item" => "Short Sword"})
    %{conn: conn}
  end

  # Each page, and the sort every table on it opens on.
  @pages [
    {"/talking-island/trader/weapons", %{"stock" => {"price", :asc}}},
    {"/talking-island/trader/sell", %{"sellable" => {"buyback", :desc}}},
    {"/inventory", %{"items" => {"slot", :asc}}},
    {"/talking-island/gatekeeper", %{"routes-table" => {"fee", :asc}}},
    {"/talking-island/guild", %{"lessons" => {"learn_at", :asc}}},
    {"/races",
     %{
       "human-classes" => {"class", :asc},
       "elf-classes" => {"class", :asc},
       "dark-elf-classes" => {"class", :asc},
       "orc-classes" => {"class", :asc}
     }},
    {"/highscores", %{"halls-table" => {"total_xp", :desc}}}
  ]

  for {path, tables} <- @pages do
    test "every table on #{path} opens on its default and turns on every header", %{conn: conn} do
      {:ok, view, html} = live(conn, unquote(path))
      tables = unquote(Macro.escape(tables))

      drawn =
        html
        |> LazyHTML.from_document()
        |> LazyHTML.query("table.data-table")
        |> LazyHTML.attribute("id")

      assert Enum.sort(drawn) == Enum.sort(Map.keys(tables))

      for {id, default} <- tables do
        assert Screens.sortable(id).default == default
        assert sorted?(view, id, default)

        headers =
          view
          |> render()
          |> LazyHTML.from_document()
          |> LazyHTML.query("##{id} th button.sort")
          |> LazyHTML.attribute("phx-value-key")

        assert Enum.sort(headers) == Enum.sort(Screens.sortable(id).keys), id

        Enum.reduce(headers, default, fn key, sort ->
          view |> element(~s(##{id} button[phx-value-key="#{key}"])) |> render_click()
          sort = Controls.next_sort(sort, key)
          assert sorted?(view, id, sort), "#{id} #{key}"
          sort
        end)
      end
    end
  end

  defp sorted?(view, id, {key, dir}) do
    aria = if dir == :asc, do: "ascending", else: "descending"
    has_element?(view, ~s(##{id} th[aria-sort="#{aria}"] button[phx-value-key="#{key}"]))
  end
end
