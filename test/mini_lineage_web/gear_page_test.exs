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

  test "a new character wears its kit, the sidebar naming its weapons and its armour as the way in" do
    {view, _session, _conn} = human(build_conn(), 0)

    assert has_element?(view, ~s(#worn-weapons a[href="/inventory"]), "Squire's Sword")

    assert has_element?(view, ~s(#worn-armour a[href="/inventory"]), "Squire's Shirt")

    view |> element("#worn-armour a", "Squire's Pants") |> render_click()
    assert_patch(view, "/inventory")
  end

  test "the village's way out leads to its trader, and Gludio's does not" do
    {view, session, _conn} = human(build_conn(), 0)

    assert has_element?(view, ~s(#travel-form option[value="trader"]))
    view |> form("#travel-form", %{"place" => "trader"}) |> render_submit()
    assert_patch(view, "/talking-island/trader")

    view |> form("#trader-form", %{"place" => "trader-swords"}) |> render_submit()
    assert_patch(view, "/talking-island/trader/swords")
    assert has_element?(view, "#stock-broadsword")
    refute has_element?(view, "#stock-bone-dagger")
    refute has_element?(view, "#stock", "two-handed")

    Characters.mutate(session, &{%{&1 | location: "gludio"}, :ok})

    {:ok, view, _html} =
      live(init_test_session(build_conn(), %{"session_id" => session}), ~p"/gludio")

    refute has_element?(view, ~s(#travel-form option[value="trader"]))
  end

  test "a purchase is paid and written at once, and the trader buys it back for half" do
    {_view, session, conn} = human(build_conn(), 20_000)
    {:ok, view, _html} = live(conn, ~p"/talking-island/trader/swords")

    view |> form("#buy-form", %{"item" => "Broadsword"}) |> render_submit()

    assert has_element?(view, "#flash", "Broadsword")
    assert stored(session).adena == 20_000 - 12_500
    sword = carried(session, "Broadsword")

    {:ok, view, _html} = live(conn, ~p"/talking-island/trader/sell")
    view |> form("#sell-form", %{"id" => sword.id}) |> render_submit()
    assert stored(session).adena == 20_000 - 12_500 + 6_250
    refute carried(session, "Broadsword")
  end

  test "a refusal is said, and nothing is paid" do
    {_view, session, conn} = human(build_conn(), 100)
    {:ok, view, _html} = live(conn, ~p"/talking-island/trader/swords")

    view |> form("#buy-form", %{"item" => "Broadsword"}) |> render_submit()

    assert has_element?(view, "#flash", "cannot afford")
    assert stored(session).adena == 100
  end

  test "the inventory lists everything, worn highlighted, and puts on, takes off and destroys apart" do
    {_view, session, conn} = human(build_conn(), 0)
    {:ok, view, _html} = live(conn, ~p"/inventory")
    dagger = carried(session, "Dagger")
    sword = carried(session, "Squire's Sword")

    assert has_element?(view, ~s(#item-#{sword.id}.owned[data-worn="true"]))
    assert has_element?(view, ~s(#item-#{dagger.id}[data-worn="false"]))

    wear = fn id -> view |> form("#wear-form", %{"id" => id}) |> render_submit() end

    # The Combat Stats beside it follow the swap: a dagger's 433 against a sword's 379.
    assert has_element?(view, ~s(#character-stats [data-key="char-atk-spd"][data-value="416"]))
    wear.(dagger.id)
    assert has_element?(view, ~s(#character-stats [data-key="char-atk-spd"][data-value="476"]))
    assert %{equipped: true} = carried(session, "Dagger")
    assert %{equipped: false} = carried(session, "Squire's Sword")
    assert has_element?(view, "#flash", "Power Strike needs a sword")

    wear.(dagger.id)
    assert %{equipped: false} = carried(session, "Dagger")

    view |> form("#destroy-form", %{"doomed" => dagger.id}) |> render_submit()
    refute carried(session, "Dagger")
    assert has_element?(view, "#flash", "destroy the Dagger")
  end

  test "the button says what the picked item needs, and nothing worn is offered for destroying" do
    {_view, session, conn} = human(build_conn(), 0)
    {:ok, view, _html} = live(conn, ~p"/inventory")
    sword = carried(session, "Squire's Sword")
    dagger = carried(session, "Dagger")

    view |> form("#wear-form", %{"id" => sword.id}) |> render_change(%{"_target" => ["id"]})
    assert has_element?(view, "#wear-form button", "Take off")
    view |> form("#wear-form", %{"id" => dagger.id}) |> render_change(%{"_target" => ["id"]})
    assert has_element?(view, "#wear-form button", "Put on")

    refute has_element?(view, ~s(#destroy-form option[value="#{sword.id}"]))
    assert has_element?(view, ~s(#destroy-form option[value="#{dagger.id}"]))
  end
end
