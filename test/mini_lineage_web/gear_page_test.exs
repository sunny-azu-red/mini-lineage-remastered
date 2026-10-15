defmodule MiniLineageWeb.GearPageTest do
  @moduledoc """
  Rules §23 and §24 in the browser's own terms: a village's trader, buying and selling written at
  once, the inventory page where gear goes on and comes off, and the sidebar showing what is equipped.
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

  test "a new character wears its kit, the sidebar naming it beside the way in" do
    {view, _session, _conn} = human(build_conn(), 0)

    assert has_element?(view, "#equipped-weapons .stat-value", "Squire's Sword")
    assert has_element?(view, "#equipped-armour .stat-value", "Squire's Shirt")
    refute has_element?(view, "#equipped-weapons a, #equipped-armour a")

    view |> element(~s(#purse a[href="/inventory"])) |> render_click()
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
    view |> form("#sell-form", %{"item" => sword.id}) |> render_submit()
    assert stored(session).adena == 20_000 - 12_500 + 6_250
    refute carried(session, "Broadsword")
  end

  test "a purchase puts the dropdown back to its start, so a second click buys nothing" do
    {_view, _session, conn} = human(build_conn(), 20_000)
    {:ok, view, _html} = live(conn, ~p"/talking-island/trader/swords")
    pick = %{"item" => "Broadsword"}

    view |> form("#buy-form", pick) |> render_change(%{"_target" => ["item"]})
    assert has_element?(view, "#buy-form button", "Buy")
    view |> form("#buy-form", pick) |> render_submit()

    assert has_element?(view, "#buy-form option[value=''][selected]")
    assert has_element?(view, "#buy-form button", "Return")
  end

  test "a refusal is said, and nothing is paid" do
    {_view, session, conn} = human(build_conn(), 100)
    {:ok, view, _html} = live(conn, ~p"/talking-island/trader/swords")

    view |> form("#buy-form", %{"item" => "Broadsword"}) |> render_submit()

    assert has_element?(view, "#flash", "cannot afford")
    assert stored(session).adena == 100
  end

  test "the inventory lists everything, equipped highlighted, and puts on, takes off and destroys apart" do
    {_view, session, conn} = human(build_conn(), 0)
    Characters.mutate(session, &{%{&1 | skills: %{"Power Strike" => 1}}, :ok})
    {:ok, view, _html} = live(conn, ~p"/inventory")
    dagger = carried(session, "Squire's Dagger")
    sword = carried(session, "Squire's Sword")

    assert has_element?(view, ~s(#item-#{sword.id}.owned[data-equipped="true"]))
    assert has_element?(view, ~s(#item-#{dagger.id}[data-equipped="false"]))
    assert has_element?(view, "#sidebar #equipped-weapons", "Squire's Sword")

    wear = fn id -> view |> form("#wear-form", %{"item" => id}) |> render_submit() end

    # The Combat Stats beside it follow the swap: a dagger's 433 against a sword's 379.
    assert has_element?(view, ~s(#character-stats [data-key="char-atk-spd"][data-value="416"]))
    wear.(dagger.id)
    assert has_element?(view, ~s(#character-stats [data-key="char-atk-spd"][data-value="476"]))
    assert %{equipped: true} = carried(session, "Squire's Dagger")
    assert %{equipped: false} = carried(session, "Squire's Sword")
    assert has_element?(view, "#sidebar #equipped-weapons", "Squire's Dagger")
    assert has_element?(view, "#flash", "Power Strike needs a sword")

    wear.(dagger.id)
    assert %{equipped: false} = carried(session, "Squire's Dagger")

    view |> form("#destroy-form", %{"doomed" => dagger.id}) |> render_submit()
    refute carried(session, "Squire's Dagger")
    assert has_element?(view, "#flash", "destroy the Squire's Dagger")
  end

  test "the inventory closes onto the page it was opened from, and onto the town after a reload" do
    {_view, session, conn} = human(build_conn(), 0)

    for from <- ["/talking-island/trader", "/talking-island/obelisk-of-victory"] do
      {:ok, view, _html} = live(conn, from)
      view |> element("#purse a", "Open") |> render_click()
      assert_patch(view, "/inventory")
      assert has_element?(view, ~s(#purse a[href="#{from}"]), "Close")

      view |> element("#purse a", "Close") |> render_click()
      assert_patch(view, from)
      refute has_element?(view, "#fight-log")
      # Rules §20: back on the ground is back in combat; the trader rests.
      assert stored(session).combat == "engaged" == (from =~ "obelisk")

      view |> element("#purse a", "Open") |> render_click()
      view |> form("#wear-form", %{"item" => ""}) |> render_submit()
      assert_patch(view, from)
    end

    {:ok, view, _html} = live(conn, ~p"/inventory")
    assert has_element?(view, ~s(#purse a[href="/talking-island"]), "Close")
  end

  test "the button says what the picked item needs, and nothing equipped is offered for destroying" do
    {_view, session, conn} = human(build_conn(), 0)
    {:ok, view, _html} = live(conn, ~p"/inventory")
    sword = carried(session, "Squire's Sword")
    dagger = carried(session, "Squire's Dagger")

    view |> form("#wear-form", %{"item" => sword.id}) |> render_change(%{"_target" => ["item"]})
    assert has_element?(view, "#wear-form button", "Take off")
    view |> form("#wear-form", %{"item" => dagger.id}) |> render_change(%{"_target" => ["item"]})
    assert has_element?(view, "#wear-form button", "Put on")

    refute has_element?(view, ~s(#destroy-form option[value="#{sword.id}"]))
    assert has_element?(view, ~s(#destroy-form option[value="#{dagger.id}"]))
  end

  test "potions are bought by the lot onto one stack, counted in the sidebar and drunk from the inventory" do
    {_view, session, conn} = human(build_conn(), 1_000)
    {:ok, view, _html} = live(conn, ~p"/talking-island/trader/potions")

    assert has_element?(view, "#stock-lesser-healing-potion")
    assert has_element?(view, ~s(#buy-form option[value="Lesser Healing Potion|10"]))
    view |> form("#buy-form", %{"item" => "Lesser Healing Potion|10"}) |> render_submit()

    assert stored(session).adena == 100
    potions = carried(session, "Lesser Healing Potion")
    assert potions.count == 10

    {:ok, view, _html} = live(conn, ~p"/talking-island")

    refute has_element?(view, "#inventory", "Lesser Healing Potion")

    Characters.mutate(session, &{%{&1 | health: 10}, :ok})
    {:ok, view, _html} = live(conn, ~p"/inventory")
    view |> form("#wear-form", %{"item" => potions.id}) |> render_change(%{"_target" => ["item"]})
    assert has_element?(view, "#wear-form button", "Drink")
    view |> form("#wear-form", %{"item" => potions.id}) |> render_submit()

    assert stored(session).health == 10 + 112
    assert carried(session, "Lesser Healing Potion").count == 9
  end

  test "the character page's orders set the share of HP a fight drinks below" do
    {_view, session, conn} = human(build_conn(), 0)
    {:ok, view, _html} = live(conn, ~p"/character")

    assert has_element?(view, "#potion-share", "below 50%")
    assert has_element?(view, ~s(#orders-form option[value="potion:50"][disabled]))
    view |> form("#orders-form", %{"order" => "potion:30"}) |> render_submit()

    assert stored(session).potion_at == 30
    assert has_element?(view, "#potion-share", "below 30%")
    view |> form("#orders-form", %{"order" => "potion:0"}) |> render_submit()
    assert has_element?(view, "#potion-share", "no potions")
  end

  # Rules §20: a character that knows no heal has none to order.
  test "once a heal is known, the orders also set when it heals, before the pull and in a fight" do
    {_view, session, conn} = human(build_conn(), 0)
    {:ok, view, _html} = live(conn, ~p"/character")
    refute has_element?(view, "#heal-pull-share")
    refute has_element?(view, ~s(#orders-form option[value="pull:30"]))

    Characters.mutate(session, &{%{&1 | skills: Map.put(&1.skills, "Self Heal", 1)}, :ok})
    {:ok, view, _html} = live(conn, ~p"/character")
    assert has_element?(view, "#heal-pull-share", "below 70%")
    assert has_element?(view, "#heal-fight-share", "never heal in a fight")

    view |> form("#orders-form", %{"order" => "pull:30"}) |> render_submit()
    view |> form("#orders-form", %{"order" => "fight:30"}) |> render_submit()

    assert %{heal_pull_at: 30, heal_fight_at: 30} = stored(session)
    assert has_element?(view, "#heal-pull-share", "below 30%")
    assert has_element?(view, "#heal-fight-share", "below 30%")
  end

  # Rules §20: a skill the orders leave unused is muted where it is listed, and said in the orders.
  test "the orders leave a skill unused and use it again, a name with a colon in it too" do
    {_view, session, conn} = human(build_conn(), 0)
    skills = %{"Power Strike" => 1, "Curse: Poison" => 1}
    Characters.mutate(session, &{%{&1 | skills: skills}, :ok})
    {:ok, view, _html} = live(conn, ~p"/character")

    assert has_element?(view, "#unused-skills", "You use every skill you know.")
    assert has_element?(view, ~s(#orders-form option[value="use:true:Power Strike"][disabled]))
    view |> form("#orders-form", %{"order" => "use:false:Curse: Poison"}) |> render_submit()
    view |> form("#orders-form", %{"order" => "use:false:Power Strike"}) |> render_submit()

    assert stored(session).unused == ["Curse: Poison", "Power Strike"]
    assert has_element?(view, "#unused-skills", "Curse: Poison and")
    assert has_element?(view, "#skill-power-strike.locked", "Left unused, by your orders.")
    assert has_element?(view, ~s(#orders-form option[value="use:false:Power Strike"][disabled]))

    view |> form("#orders-form", %{"order" => "use:true:Power Strike"}) |> render_submit()
    assert stored(session).unused == ["Curse: Poison"]
    refute has_element?(view, "#skill-power-strike.locked")
  end
end
