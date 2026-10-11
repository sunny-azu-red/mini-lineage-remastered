defmodule MiniLineageWeb.GearPageTest do
  @moduledoc """
  Rules §23 and §24 in the browser's own terms: a village's trader, buying and selling written at
  once, the inventory page where gear goes on and comes off, and the sidebar showing what is worn.
  """
  use MiniLineageWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import MiniLineage.DataCase, only: [stored: 1]

  alias MiniLineage.Characters

  # A Human Fighter on Talking Island with `adena` to spend.
  defp human(conn, adena) do
    session = Characters.new_session_id()
    on_exit(fn -> Characters.forget(session) end)
    conn = init_test_session(conn, %{"session_id" => session})
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> element("form[phx-submit=start]")
    |> render_submit(%{"name" => "Shopper", "race_id" => "0", "path" => "fighter"})

    Characters.mutate(session, &{%{&1 | adena: adena}, :ok})
    {view, session, conn}
  end

  defp carried(session, name), do: Enum.find(stored(session).items, &(&1.name == name))

  test "a new character wears its kit, which the sidebar shows, with a way to its inventory" do
    {view, _session, _conn} = human(build_conn(), 0)

    assert has_element?(view, "#inventory .stat-value", "Squire's Sword")
    assert has_element?(view, "#inventory .stat-value", "Squire's Shirt")
    assert has_element?(view, "#open-inventory")
  end

  test "the village's way out leads to its trader, and Gludio's does not" do
    {view, session, _conn} = human(build_conn(), 0)

    assert has_element?(view, ~s(#travel-form option[value="trader"]))
    view |> form("#travel-form", %{"place" => "trader"}) |> render_submit()
    assert_patch(view, "/talking-island/trader")
    assert has_element?(view, "#stock-broadsword")

    Characters.mutate(session, &{%{&1 | location: "gludio"}, :ok})

    {:ok, view, _html} =
      live(init_test_session(build_conn(), %{"session_id" => session}), ~p"/gludio")

    refute has_element?(view, ~s(#travel-form option[value="trader"]))
  end

  test "a purchase is paid and written at once, and the trader buys it back for half" do
    {_view, session, conn} = human(build_conn(), 20_000)
    {:ok, view, _html} = live(conn, ~p"/talking-island/trader")

    view |> element("#stock-broadsword button") |> render_click()

    assert has_element?(view, "#flash", "Broadsword")
    assert stored(session).adena == 20_000 - 14_375
    sword = carried(session, "Broadsword")

    view |> element("#sell-#{sword.id} button") |> render_click()
    assert stored(session).adena == 20_000 - 14_375 + 6_250
    refute carried(session, "Broadsword")
  end

  test "a refusal is said, and nothing is paid" do
    {_view, session, conn} = human(build_conn(), 100)
    {:ok, view, _html} = live(conn, ~p"/talking-island/trader")

    view |> element("#stock-broadsword button") |> render_click()

    assert has_element?(view, "#flash", "cannot afford")
    assert stored(session).adena == 100
  end

  test "the inventory puts gear on and takes it off, written at once and shown in the sidebar" do
    {_view, session, conn} = human(build_conn(), 0)
    {:ok, view, _html} = live(conn, ~p"/inventory")
    dagger = carried(session, "Dagger")

    view |> element("#item-#{dagger.id} button") |> render_click()

    assert %{equipped: true} = carried(session, "Dagger")
    assert %{equipped: false} = carried(session, "Squire's Sword")
    assert has_element?(view, ~s(#item-#{dagger.id}[data-worn="true"]))

    view |> element("#item-#{dagger.id} button") |> render_click()
    assert %{equipped: false} = carried(session, "Dagger")
  end

  test "a character cannot reach another village's trader" do
    {_view, session, conn} = human(build_conn(), 0)

    {:error, {:live_redirect, %{to: "/talking-island"}}} = live(conn, ~p"/orc-village/trader")
    assert stored(session).location == "talking-island"
  end
end
