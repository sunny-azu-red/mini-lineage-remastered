defmodule MiniLineageWeb.GearPageTest do
  @moduledoc """
  Rules §23 and §24 in the browser's own terms: a village's trader, buying and selling written at
  once, the inventory page where gear goes on and comes off, and the sidebar showing what is equipped.
  """
  use MiniLineageWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import MiniLineage.DataCase, only: [stored: 1]

  alias MiniLineage.Characters
  alias MiniLineage.Game.Rules

  # A Human Fighter on Talking Island with `adena` to spend.
  defp human(conn, adena), do: shopper(conn, "0", "fighter", adena)

  # A new character of `race_id` and `path` in its own village, with `adena` to spend.
  defp shopper(conn, race_id, path, adena) do
    session = Characters.new_session_id()
    on_exit(fn -> Characters.forget(session) end)
    conn = init_test_session(conn, %{"session_id" => session})
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> element("form[phx-submit=start]")
    |> render_submit(%{"name" => "Shopper", "race_id" => race_id, "path" => path})

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

  test "a necklace is named before the shirt and pants, in the sidebar and the inventory" do
    {_view, session, conn} = human(build_conn(), 20_000)
    {:ok, view, _html} = live(conn, ~p"/talking-island-village/traders/magic-trader")
    view |> form("#buy-form", %{"item" => "Necklace of Magic"}) |> render_submit()
    necklace = carried(session, "Necklace of Magic")

    {:ok, view, _html} = live(conn, ~p"/inventory")

    unless necklace.equipped,
      do: view |> form("#inventory-form", %{"item" => "equip:#{necklace.id}"}) |> render_submit()

    doc = view |> render() |> LazyHTML.from_document()
    texts = &(doc |> LazyHTML.query(&1) |> Enum.map(fn node -> LazyHTML.text(node) end))

    assert [neck, shirt, pants] = texts.("#equipped-armour .stat-value")
    assert neck =~ "Necklace" and shirt =~ "Shirt" and pants =~ "Pants"

    assert Enum.take(texts.("#items tbody tr[data-equipped=true] td:last-child"), -3) ==
             ~w(Necklace Chest Legs)
  end

  test "the village's way out leads to its traders, each by name, and Gludio's does not" do
    {view, session, _conn} = human(build_conn(), 0)

    assert has_element?(view, ~s(#travel-form option[value="trader"]), "🛒 Traders")
    view |> form("#travel-form", %{"place" => "trader"}) |> render_submit()
    assert_patch(view, "/talking-island-village/traders")

    assert has_element?(
             view,
             "#trader-intro",
             "Lector sells weapons, Jackson armour and shields, and Silvia and Katerina jewellery and potions"
           )

    for page <- ~w(weapon armour magic sell),
        do: assert(has_element?(view, ~s(#trader-form option[value="trader-#{page}"])))

    view |> form("#trader-form", %{"place" => "trader-weapon"}) |> render_submit()
    assert_patch(view, "/talking-island-village/traders/weapon-trader")
    assert has_element?(view, "#screen h2", "Weapon Trader")
    assert has_element?(view, "#trader-intro", "Lector lays out the weapons")
    assert has_element?(view, "#stock-broadsword", "Broadsword ✋")
    assert has_element?(view, "#stock-short-bow", "Short Bow 👐")
    assert has_element?(view, ~s(#buy-form optgroup[label="Daggers"] option[value="Bone Dagger"]))

    Characters.mutate(session, &{%{&1 | location: "town-of-gludio"}, :ok})

    {:ok, view, _html} =
      live(init_test_session(build_conn(), %{"session_id" => session}), ~p"/town-of-gludio")

    refute has_element?(view, ~s(#travel-form option[value="trader"]))
  end

  test "a Fighter is shown its own weapons, light armour and every shield" do
    {_view, _session, conn} = human(build_conn(), 0)

    {:ok, view, _html} = live(conn, ~p"/talking-island-village/traders/weapon-trader")
    assert has_element?(view, "#stock-bone-dagger")
    assert has_element?(view, "#stock-short-bow")
    refute has_element?(view, "#stock-buffalos-horn")
    assert shelves(view) == ~w(shelf-swords shelf-daggers shelf-bows)
    assert has_element?(view, "#stock #shelf-swords tr.shelf th", "Swords")
    assert has_element?(view, "#shelf-swords tr.shelf + tr#stock-short-sword")
    assert has_element?(view, "#buy-form optgroup:first-of-type[label=Swords]")

    {:ok, view, _html} = live(conn, ~p"/talking-island-village/traders/armour-trader")
    assert has_element?(view, "#screen h2", "Armour Trader")
    assert has_element?(view, "#stock-small-shield")
    assert has_element?(view, "#stock-leather-shirt")
    refute has_element?(view, "#stock-cotton-tunic")
    assert shelves(view) == ~w(shelf-shields shelf-light-armour)
    assert has_element?(view, "#shelf-shields tr.shelf th", "Shields")
    assert has_element?(view, "#shelf-light-armour tr.shelf th", "Light Armour")
    assert has_element?(view, "#shelf-light-armour #stock-leather-shirt")
    assert has_element?(view, "#shelf-light-armour #stock-leather-pants")
    assert has_element?(view, "#buy-form optgroup:first-of-type[label=Shields]")
    assert has_element?(view, ~s(#buy-form optgroup[label="Light Armour"]))
  end

  test "a Mystic's chest and legs are one shelf of robes" do
    {_view, _session, conn} = shopper(build_conn(), "0", "mystic", 0)

    {:ok, view, _html} = live(conn, ~p"/talking-island-village/traders/armour-trader")
    assert shelves(view) == ~w(shelf-shields shelf-robes)
    assert has_element?(view, "#shelf-robes tr.shelf th", "Robes")
    assert has_element?(view, "#shelf-robes #stock-cotton-tunic")
    assert has_element?(view, "#shelf-robes #stock-cotton-stockings")
    assert has_element?(view, ~s(#buy-form optgroup[label="Robes"]))
  end

  test "the jeweller and the grocer keep one Magic Trader, necklaces then potions, both greeting you" do
    {_view, _session, conn} = human(build_conn(), 0)
    {:ok, view, _html} = live(conn, ~p"/talking-island-village/traders/magic-trader")

    assert has_element?(view, "#screen h2", "Magic Trader")
    assert has_element?(view, "#trader-intro", "Silvia minds the jewellery")

    assert has_element?(
             view,
             "#trader-intro",
             "while Katerina wishes you the luck of the goddess"
           )

    assert shelves(view) == ~w(shelf-necklaces shelf-potions)
    assert has_element?(view, "#shelf-potions tr.shelf th", "Potions")
    assert has_element?(view, "#buy-form optgroup:first-of-type[label=Necklaces]")
    assert has_element?(view, ~s(#buy-form optgroup[label="Potions"] option[value$="|10"]))
  end

  test "a page of one shelf has no heading to tell it apart, nor a group" do
    {_view, _session, conn} = shopper(build_conn(), "3", "fighter", 0)
    {:ok, view, _html} = live(conn, ~p"/dark-elf-village/traders/weapon-trader")

    assert shelves(view) == ~w(shelf-daggers)
    assert has_element?(view, "#stock tbody tr[id^=stock-]")
    refute has_element?(view, "#stock tr.shelf")
    refute has_element?(view, "#buy-form optgroup")
  end

  test "one table opens cheapest first and sorts within each shelf, by name and not its emoji" do
    {_view, _session, conn} = human(build_conn(), 0)
    {:ok, view, _html} = live(conn, ~p"/talking-island-village/traders/weapon-trader")
    first = &has_element?(view, "#shelf-#{&1} tr.shelf + tr#stock-#{&2}")

    offered =
      &has_element?(view, ~s(#buy-form optgroup[label="#{&1}"] option:first-child[value="#{&2}"]))

    assert has_element?(view, ~s(#stock th[aria-sort="ascending"]), "Adena")
    assert first.("swords", "short-sword") and first.("bows", "short-bow")

    view |> element(~s(#stock button[phx-value-key="name"])) |> render_click()
    assert has_element?(view, ~s(#stock th[aria-sort="ascending"]), "Item")
    assert first.("swords", "brandish") and offered.("Swords", "Brandish")
    assert first.("bows", "bow") and offered.("Bows", "Bow")
    assert shelves(view) == ~w(shelf-swords shelf-daggers shelf-bows)
    refute has_element?(view, "#shelf-swords [id$=bow]")
  end

  defp shelves(view) do
    view
    |> render()
    |> LazyHTML.from_document()
    |> LazyHTML.query("#stock tbody")
    |> LazyHTML.attribute("id")
  end

  test "a Mystic is shown staves, robes and every shield, and sold nothing else" do
    {_view, session, conn} = shopper(build_conn(), "1", "mystic", 20_000)

    {:ok, view, _html} = live(conn, ~p"/orc-village/traders/weapon-trader")
    assert has_element?(view, "#trader-intro", "Jakal greets you")
    assert has_element?(view, "#stock-buffalos-horn")
    refute has_element?(view, "#stock-broadsword")
    refute has_element?(view, "#stock-spiked-gloves")

    {:ok, view, _html} = live(conn, ~p"/orc-village/traders/armour-trader")
    assert has_element?(view, "#stock-cotton-tunic")
    assert has_element?(view, "#stock-small-shield")
    refute has_element?(view, "#stock-leather-shirt")

    render_hook(view, "buy", %{"item" => "Broadsword"})
    assert has_element?(view, "#flash", "does not sell that")
    assert stored(session).adena == 20_000
  end

  test "a purchase is paid and written at once, and the trader buys it back for half" do
    {_view, session, conn} = human(build_conn(), 20_000)
    {:ok, view, _html} = live(conn, ~p"/talking-island-village/traders/weapon-trader")

    view |> form("#buy-form", %{"item" => "Broadsword"}) |> render_submit()

    assert has_element?(view, "#flash", "Broadsword")
    assert stored(session).adena == 20_000 - 12_500
    sword = carried(session, "Broadsword")

    {:ok, view, _html} = live(conn, ~p"/talking-island-village/traders/sell")
    view |> form("#sell-form", %{"item" => sword.id}) |> render_submit()
    assert stored(session).adena == 20_000 - 12_500 + 6_250
    refute carried(session, "Broadsword")
  end

  test "a purchase puts the dropdown back to its start, so a second click buys nothing" do
    {_view, _session, conn} = human(build_conn(), 20_000)
    {:ok, view, _html} = live(conn, ~p"/talking-island-village/traders/weapon-trader")
    pick = %{"item" => "Broadsword"}

    view |> form("#buy-form", pick) |> render_change(%{"_target" => ["item"]})
    assert has_element?(view, "#buy-form button", "Buy")
    view |> form("#buy-form", pick) |> render_submit()

    assert has_element?(view, "#buy-form option[value=''][selected]")
    assert has_element?(view, "#buy-form button", "Return")
  end

  test "a refusal is said, and nothing is paid" do
    {_view, session, conn} = human(build_conn(), 100)
    {:ok, view, _html} = live(conn, ~p"/talking-island-village/traders/weapon-trader")

    view |> form("#buy-form", %{"item" => "Broadsword"}) |> render_submit()

    assert has_element?(view, "#flash", "cannot afford")
    assert stored(session).adena == 100
  end

  test "an inventory emptied says so, with no table left to head" do
    {_view, session, conn} = human(build_conn(), 0)
    Characters.mutate(session, &{%{&1 | items: []}, :ok})
    {:ok, view, _html} = live(conn, ~p"/inventory")

    assert render(element(view, "#inventory-count")) =~
             "You carry nothing, with room for #{Rules.capacity()} things."

    refute has_element?(view, "#items")
  end

  # `MiniLineageWeb.Kept`: the bag is the one table that remembers, served in the reader's sort.
  test "the inventory is served in the sort the reader left it in" do
    {_view, session, conn} = human(build_conn(), 0)
    kept = put_req_cookie(conn, MiniLineageWeb.Kept.cookie(), "table%3Aitems=name%3Adesc")

    by_name =
      stored(session).items |> Enum.sort_by(& &1.name, :desc) |> Enum.map(&"item-#{&1.id}")

    doc = kept |> get(~p"/inventory") |> html_response(200) |> LazyHTML.from_document()
    assert doc |> LazyHTML.query("#items tbody tr") |> LazyHTML.attribute("id") == by_name

    assert LazyHTML.query(doc, ~s(#items-head[phx-hook="Table"][data-sort="name:desc"]))
           |> Enum.count() == 1

    {:ok, view, _html} = live(kept, ~p"/inventory")
    assert has_element?(view, ~s(#items th[aria-sort="descending"]), "Item")
  end

  test "the inventory lists everything, equipped highlighted, and equips, unequips and destroys" do
    {_view, session, conn} = human(build_conn(), 0)
    Characters.mutate(session, &{%{&1 | skills: %{"Power Strike" => 1}}, :ok})
    {:ok, view, _html} = live(conn, ~p"/inventory")
    dagger = carried(session, "Squire's Dagger")
    sword = carried(session, "Squire's Sword")

    assert has_element?(view, ~s(#item-#{sword.id}.owned[data-equipped="true"]))
    assert has_element?(view, ~s(#item-#{dagger.id}[data-equipped="false"]))
    assert has_element?(view, "#sidebar #equipped-weapons", "Squire's Sword")

    act = fn choice -> view |> form("#inventory-form", %{"item" => choice}) |> render_submit() end

    # Second tier: the bag is the page, and the stats beside it fold.
    assert has_element?(view, ~s(#combat-stats[phx-hook="Panel"] > h2 > button.panel-toggle))
    refute has_element?(view, "#screen > .panel:first-child .panel-toggle")

    # The Combat Stats beside it follow the swap: a dagger's 433 against a sword's 379.
    assert has_element?(view, ~s(#character-stats [data-key="char-atk-spd"][data-value="416"]))
    act.("equip:#{dagger.id}")
    assert has_element?(view, ~s(#character-stats [data-key="char-atk-spd"][data-value="476"]))
    assert %{equipped: true} = carried(session, "Squire's Dagger")
    assert %{equipped: false} = carried(session, "Squire's Sword")
    assert has_element?(view, "#sidebar #equipped-weapons", "Squire's Dagger")
    assert has_element?(view, "#flash", "your Power Strike skill needs a sword")

    act.("unequip:#{dagger.id}")
    assert %{equipped: false} = carried(session, "Squire's Dagger")
    assert has_element?(view, "#flash", "You unequip the Squire's Dagger")

    act.("destroy:#{dagger.id}")
    refute carried(session, "Squire's Dagger")
    assert has_element?(view, "#flash", "destroy the Squire's Dagger")
  end

  test "the inventory closes onto the page it was opened from, and onto the town after a reload" do
    {_view, session, conn} = human(build_conn(), 0)

    for from <- ["/talking-island-village/traders", "/talking-island-village/obelisk-of-victory"] do
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
      view |> form("#inventory-form", %{"item" => ""}) |> render_submit()
      assert_patch(view, from)
    end

    {:ok, view, _html} = live(conn, ~p"/inventory")
    assert has_element?(view, ~s(#purse a[href="/talking-island-village"]), "Close")
  end

  test "one list groups each item under what can be done with it, and the button says the verb" do
    {_view, session, conn} = human(build_conn(), 0)
    {:ok, view, _html} = live(conn, ~p"/inventory")
    sword = carried(session, "Squire's Sword")
    dagger = carried(session, "Squire's Dagger")

    under = fn group, choice ->
      ~s(#inventory-form optgroup[label="#{group}"] option[value="#{choice}"])
    end

    pick = fn choice ->
      view
      |> form("#inventory-form", %{"item" => choice})
      |> render_change(%{"_target" => ["item"]})
    end

    assert has_element?(view, under.("Unequip", "unequip:#{sword.id}"))
    assert has_element?(view, under.("Equip", "equip:#{dagger.id}"))
    assert has_element?(view, under.("Destroy", "destroy:#{dagger.id}"))
    refute has_element?(view, ~s(#inventory-form option[value="destroy:#{sword.id}"]))
    refute has_element?(view, ~s(#inventory-form option[value="equip:#{sword.id}"]))

    pick.("unequip:#{sword.id}")
    assert has_element?(view, "#inventory-form button:not(.btn-danger)", "Unequip")
    pick.("equip:#{dagger.id}")
    assert has_element?(view, "#inventory-form button:not(.btn-danger)", "Equip")
    pick.("destroy:#{dagger.id}")
    assert has_element?(view, "#inventory-form button.btn-danger", "Destroy")
  end

  test "potions are bought by the lot onto one stack, counted in the sidebar and drunk from the inventory" do
    {_view, session, conn} = human(build_conn(), 1_000)
    {:ok, view, _html} = live(conn, ~p"/talking-island-village/traders/magic-trader")

    assert has_element?(view, "#stock-lesser-healing-potion")
    assert has_element?(view, ~s(#buy-form option[value="Lesser Healing Potion|10"]))
    view |> form("#buy-form", %{"item" => "Lesser Healing Potion|10"}) |> render_submit()

    assert stored(session).adena == 100
    potions = carried(session, "Lesser Healing Potion")
    assert potions.count == 10

    {:ok, view, _html} = live(conn, ~p"/talking-island-village")

    refute has_element?(view, "#inventory", "Lesser Healing Potion")

    assert has_element?(
             view,
             ~s(#consumable-#{potions.id} [title="Lesser Healing Potion"]),
             "🧪 Lesser Healing"
           )

    refute has_element?(view, "#consumables", "Lesser Healing Potion")

    assert has_element?(
             view,
             ~s(#consumable-#{potions.id} [data-key="consumable-#{potions.id}"][data-value="10"])
           )

    Characters.mutate(session, &{%{&1 | health: 10}, :ok})
    {:ok, view, _html} = live(conn, ~p"/inventory")
    drink = "drink:#{potions.id}"
    refute has_element?(view, ~s(#inventory-form option[value="equip:#{potions.id}"]))
    view |> form("#inventory-form", %{"item" => drink}) |> render_change(%{"_target" => ["item"]})
    assert has_element?(view, "#inventory-form button", "Drink")
    view |> form("#inventory-form", %{"item" => drink}) |> render_submit()

    assert stored(session).health == 10 + 112
    assert carried(session, "Lesser Healing Potion").count == 9

    assert has_element?(
             view,
             ~s(#consumables [data-key="consumable-#{potions.id}"][data-value="9"])
           )
  end
end
