defmodule MiniLineageWeb.HuntPageTest do
  @moduledoc """
  Rules §17, §20 and §21 in the browser's own terms: the village's way out to its ground, the one
  click that fights, what a kill writes at once, and a death that ends the run. The dice are pinned
  inside the character's process, where the fight runs.
  """
  use MiniLineageWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import MiniLineage.DataCase, only: [stored: 1]

  alias MiniLineage.{Characters, Repo}
  alias MiniLineage.Characters.Record
  alias MiniLineage.Game.{Math, Narratives, Player, Rng}

  # A Human Fighter, standing on Talking Island.
  defp human(conn) do
    session = Characters.new_session_id()
    on_exit(fn -> Characters.forget(session) end)
    conn = init_test_session(conn, %{"session_id" => session})
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> element("form[phx-submit=start]")
    |> render_submit(%{"name" => "Squire", "race_id" => "0", "path" => "fighter"})

    {view, session, conn}
  end

  defp text(view, selector),
    do:
      view
      |> element(selector)
      |> render()
      |> LazyHTML.from_fragment()
      |> LazyHTML.text()
      |> String.trim()

  # Rules §20: where the button sends the hunt next, which it names only once a fight is held.
  defp moves, do: Enum.map(Narratives.moves("obelisk-of-victory"), &"⚔️ #{&1}")

  defp pin(session, value) do
    Characters.mutate(session, fn player ->
      Rng.put_source(fn -> value end)
      {player, :ok}
    end)
  end

  test "going out to the ground meets nothing but is combat, and looking for action is the first fight" do
    {view, session, _conn} = human(build_conn())
    pin(session, 0.0)

    assert has_element?(view, ~s(#travel-form option[value="hunt"]), "Obelisk of Victory")
    view |> form("#travel-form", %{"place" => "hunt"}) |> render_submit()

    assert_patch(view, "/talking-island/obelisk-of-victory")
    assert has_element?(view, "#sidebar")
    refute has_element?(view, "#fight")
    assert text(view, "#hunt-button") == "⚔️ Hunt"
    assert text(view, "#retreat-button") == "Retreat"
    assert has_element?(view, "#effects [data-effect-id=combat]")
    assert stored(session).combat == "engaged"

    view |> element("#hunt-button") |> render_click()

    assert has_element?(view, "#fight #fight-log li", "You meet")
    assert text(view, "#hunt-button") in moves()
    assert stored(session).combat == "engaged"
  end

  test "retreating goes back to town, disengaging" do
    {_view, session, conn} = human(build_conn())
    pin(session, 0.0)
    {:ok, view, _html} = live(conn, ~p"/talking-island/obelisk-of-victory")
    view |> element("#hunt-button") |> render_click()

    view |> element("#retreat-button") |> render_click()

    assert_patch(view, "/talking-island")
    assert is_integer(stored(session).combat)
  end

  test "and so does leaving the ground any other way" do
    {_view, session, conn} = human(build_conn())
    pin(session, 0.0)
    {:ok, view, _html} = live(conn, ~p"/talking-island/obelisk-of-victory")
    view |> element("#hunt-button") |> render_click()

    view |> element("#header-link") |> render_click()

    assert is_integer(stored(session).combat)
  end

  test "the button never names the same place twice running, and a new visit draws the last fight" do
    {_view, session, conn} = human(build_conn())
    # Far enough from the next level that no kill here reaches it, so each outcome is a plain one.
    Characters.mutate(session, &{%{&1 | experience: Math.xp_for_level(3)}, :ok})
    pin(session, 0.0)
    {:ok, view, _html} = live(conn, ~p"/talking-island/obelisk-of-victory")

    view |> element("#hunt-button") |> render_click()
    assert has_element?(view, "#fight-outcome.victory", "cut down")
    first = text(view, "#hunt-button")
    view |> element("#hunt-button") |> render_click()
    second = text(view, "#hunt-button")

    assert first in moves() and second in moves() and first != second

    {:ok, view, _html} = live(conn, ~p"/talking-island/obelisk-of-victory")

    # Read back from `encounters`, so a reload or a return finds it; the button has named nothing yet.
    assert has_element?(view, "#fight #fight-outcome.victory", "cut down")
    assert text(view, "#hunt-button") == "⚔️ Hunt"

    view |> element("#retreat-button") |> render_click()
    {:ok, view, _html} = live(conn, ~p"/talking-island/obelisk-of-victory")
    assert has_element?(view, "#fight #fight-outcome.victory", "cut down")
  end

  test "a character cannot hunt another village's ground" do
    {_view, session, conn} = human(build_conn())

    {:error, {:live_redirect, %{to: "/talking-island"}}} =
      live(conn, ~p"/orc-village/cave-of-trials")

    assert stored(session).location == "talking-island"
  end

  test "a kill pays EXP, SP and Adena, written at once, and the character stays to hunt again" do
    {_view, session, conn} = human(build_conn())
    pin(session, 0.0)
    {:ok, view, _html} = live(conn, ~p"/talking-island/obelisk-of-victory")

    view |> element("#hunt-button") |> render_click()

    # Written on the ground's page, not in an alert, with where both stand after each round.
    refute has_element?(view, "#flash")
    assert has_element?(view, "#fight-outcome", "cut down")
    assert has_element?(view, "#fight h2", "Fight Log")
    # A monster that waits to be met opens the log as an Encounter, washed as an info alert is.
    assert has_element?(view, "#fight-log > li.encounter:first-child .entry-head", "Encounter")
    assert has_element?(view, "#fight-log li", "You meet")
    assert has_element?(view, "#fight-log li .entry-head", "Round 1 • 0.0s")

    assert has_element?(
             view,
             "#fight-log li .entry-head > span:last-child",
             ~r/^Foe \d+% • You \d+%$/
           )

    # A head is a label: when and where both stand, muted, nothing in it coloured as a value.
    for class <- ~w(speed hp level),
        do: refute(has_element?(view, "#fight-log .entry-head .#{class}"))

    refute has_element?(view, "#fight-log li p", "HP, you at")
    assert has_element?(view, "#screen[data-screen=hunt]")
    player = stored(session)
    assert player.experience > 0 and player.sp > 0 and player.adena > 0
  end

  test "a kill that levels raises the gold alert and its fanfare over the fight" do
    {_view, session, conn} = human(build_conn())
    Characters.mutate(session, &{%{&1 | experience: Math.xp_for_level(2) - 1}, :ok})
    pin(session, 0.0)
    {:ok, view, _html} = live(conn, ~p"/talking-island/obelisk-of-victory")

    view |> element("#hunt-button") |> render_click()

    assert has_element?(
             view,
             "#levelled.alert-triumph",
             "Congratulations! You have reached Level 2."
           )

    # The kill is still a victory, its new level named at the right of its head, never in its line.
    assert has_element?(view, "#fight-outcome.victory .entry-head", "Level Up")
    refute has_element?(view, "#fight-outcome p", "Level 2")
    refute has_element?(view, "#flash")
    assert_push_event(view, "play-sound", %{name: "level"})
  end

  test "a death ends the run on the ground, where it stays, a ghost, until it begins again" do
    {_view, session, conn} = human(build_conn())
    id = Characters.character_id(session)

    # Stripped and at 1 HP, with every roll landing for both sides: two critical blows cannot fell a
    # level 1 monster, and its first blow, in the second round, ends the run.
    Characters.mutate(session, fn p ->
      {%{p | health: 1, items: Enum.map(p.items, &%{&1 | equipped: false})}, :ok}
    end)

    pin(session, 0.0)
    {:ok, view, _html} = live(conn, ~p"/talking-island/obelisk-of-victory")

    view |> element("#hunt-button") |> render_click()

    assert_push_event(view, "play-sound", %{name: "death"})
    assert %{dead: true, session_id: ^session} = Repo.get!(Record, id)
    ground = ~p"/talking-island/obelisk-of-victory"

    # A reload draws what the click did.
    {:ok, reloaded, _html} = live(conn, ground)

    for view <- [view, reloaded] do
      assert has_element?(view, "#screen[data-screen=hunt]")
      assert has_element?(view, "#fight-outcome.defeat", "your road ends here")
      # The dice are pinned at 0.0, which draws the pool's first line.
      assert has_element?(view, "#death-line .deaths", "The darkness takes you.")
      # The Monument's own emoji, as its page is headed, never the Fight Log's 📜 beside it.
      assert has_element?(
               view,
               ~s(#monument-button[href="/highscores/human"][data-no-autofocus]),
               "🏛️ Monument of Heroes"
             )

      assert has_element?(view, "#restart-button[data-no-autofocus]", "Play Again")
      assert has_element?(view, "[data-effect-id=ghost]")
      refute has_element?(view, "#hunt-button")
      refute has_element?(view, "#orders")
      refute has_element?(view, "#flash")
      # Both bars empty, and neither warns of what is already over; the vital panel wears a skull.
      assert has_element?(view, ~s(#sidebar [data-key="hp"][data-value="0"]))
      assert has_element?(view, ~s(#sidebar [data-key="mp"][data-value="0"]))
      refute has_element?(view, "#sidebar .low-hp, #sidebar .low-mp")
      assert has_element?(view, ".vital-panel .header-name", "☠️ Human Fighter")
    end

    # Its own page tells the run in the past, nothing mending and nothing left to hold.
    {:ok, character, _html} = live(conn, ~p"/character")

    assert has_element?(
             character,
             "#character-vitality",
             ~r/You fell to the [A-Z][\w ]+ at the Obelisk of Victory at Level 1 /
           )

    assert has_element?(character, "#character-class", "You were a Human Fighter")
    assert has_element?(character, ".header-name", "☠️ Squire of Human Ancestry")
    assert has_element?(character, "#character-stats", "You struck with")
    refute has_element?(character, "#character-vitality", "mending")

    # Anywhere it could act sends it back; its own pages it may read, its inventory only to look.
    for path <- [~p"/", ~p"/talking-island", ~p"/talking-island/traders"] do
      assert {:error, {:live_redirect, %{to: ^ground}}} = live(conn, path), path
    end

    {:ok, inventory, _html} = live(conn, ~p"/inventory")

    assert has_element?(
             inventory,
             "#inventory-count",
             ~r/^\s*You carried \d+ of the \d+ things you could\.\s*$/
           )

    refute has_element?(inventory, "#inventory-form option[value^=equip]")
    assert has_element?(inventory, "#inventory-form button")

    reloaded |> element("#restart-button") |> render_click()
    assert_patch(reloaded, "/")
    assert has_element?(reloaded, "#screen[data-screen=start]")
    assert %{dead: true, session_id: nil} = Repo.get!(Record, id)
  end

  # Rules §20 and §26: settings, not places, so a slider and a switch rather than a dropdown, and
  # the control says what is set rather than an alert.
  defp ground(conn), do: live(conn, ~p"/talking-island/obelisk-of-victory")

  # Rules §26: a stack of potions, which the orders ask about only while one is carried.
  defp carry_potions(session),
    do:
      Characters.mutate(session, fn p ->
        {%{p | items: p.items ++ [Player.new_item("Lesser Healing Potion", false, 10)]}, :ok}
      end)

  defp slide(view, kind, stop),
    do:
      view
      |> element("#orders-form")
      |> render_change(%{"_target" => [kind], kind => to_string(stop)})

  test "the ground's orders ask when to drink only while a potion is carried" do
    {_view, session, conn} = human(build_conn())
    {:ok, view, _html} = ground(conn)
    refute has_element?(view, "#potion-order")

    carry_potions(session)
    {:ok, view, _html} = ground(conn)
    assert has_element?(view, "#potion-order #potion-share")
    assert text(view, "#potion-order label") == "🧪 Drink Healing Potion"

    # As a stack drunk dry leaves the inventory.
    Characters.mutate(
      session,
      &{%{&1 | items: Enum.reject(&1.items, fn i -> i.name == "Lesser Healing Potion" end)}, :ok}
    )

    {:ok, view, _html} = ground(conn)
    refute has_element?(view, "#potion-order")
  end

  test "the ground's orders set the share of HP a fight drinks below, saying nothing" do
    {_view, session, conn} = human(build_conn())
    carry_potions(session)
    {:ok, view, _html} = ground(conn)

    assert has_element?(view, ~s(#potion-share[value="2"][aria-valuetext="below 50% HP"]))
    assert text(view, "#potion-share-value") == "below 50% HP"
    slide(view, "potion", 1)

    assert stored(session).potion_at == 30
    assert has_element?(view, ~s(#potion-share[value="1"]))
    assert text(view, "#potion-share-value") == "below 30% HP"
    refute has_element?(view, ".alert")

    slide(view, "potion", 0)
    assert text(view, "#potion-share-value") == "never"
    assert stored(session).potion_at == 0

    # A stop past either end, or not a stop at all, changes nothing.
    for stop <- ["4", "-1", "x"], do: slide(view, "potion", stop)
    assert stored(session).potion_at == 0
  end

  test "the orders sit under the ground, and under the last fight once one is held" do
    {view, session, _conn} = human(build_conn())
    view |> form("#travel-form", %{"place" => "hunt"}) |> render_submit()
    assert has_element?(view, "#screen > .panel:nth-child(2)#orders")
    # Second tier, folding as the reader likes; the fight is the ground's, and stays open.
    assert has_element?(view, ~s(#orders[phx-hook="Panel"] > h2 > button.panel-toggle))
    refute has_element?(view, "#screen > .panel:first-child .panel-toggle")

    pin(session, 0.0)
    view |> element("#hunt-button") |> render_click()
    assert has_element?(view, "#fight + #orders")
    refute has_element?(view, "#fight .panel-toggle")
  end

  # `MiniLineageWeb.Kept`: a reload is served as the reader left it, so nothing moves on connect.
  test "the orders are served folded or open as the reader left them, the browser's cookie first" do
    {_view, _session, conn} = human(build_conn())
    ground = ~p"/talking-island/obelisk-of-victory"
    kept = fn conn, raw -> put_req_cookie(conn, MiniLineageWeb.Kept.cookie(), raw) end

    served = fn conn ->
      conn
      |> get(ground)
      |> html_response(200)
      |> LazyHTML.from_document()
      |> LazyHTML.query("#orders .panel-toggle")
      |> LazyHTML.attribute("aria-expanded")
    end

    assert served.(conn) == ["true"]
    assert served.(kept.(conn, "panel%3Aorders=0")) == ["false"]

    {:ok, view, _html} = live(kept.(conn, "panel%3Aorders=0"), ground)
    assert has_element?(view, ~s(#orders .panel-toggle[aria-expanded="false"]))

    # A reconnect rejoins with the page's copy, so the cookie as it stands now is handed over.
    newer =
      conn |> kept.("panel%3Aorders=0") |> put_connect_params(%{"kept" => "panel%3Aorders=1"})

    {:ok, view, _html} = live(newer, ground)
    assert has_element?(view, ~s(#orders .panel-toggle[aria-expanded="true"]))
  end

  test "a fold the browser reports is how the orders are drawn on coming back to the ground" do
    {view, _session, _conn} = human(build_conn())
    view |> form("#travel-form", %{"place" => "hunt"}) |> render_submit()

    render_hook(view, "fold", %{"panel" => "orders", "open" => false})
    render_hook(view, "fold", %{"panel" => "<orders>", "open" => true})
    render_hook(view, "fold", %{"panel" => "orders", "open" => "yes"})
    view |> element("#retreat-button") |> render_click()
    view |> form("#travel-form", %{"place" => "hunt"}) |> render_submit()

    assert has_element?(view, ~s(#orders .panel-toggle[aria-expanded="false"]))
  end

  # Rules §25: SP is what the guild's lessons cost, so it is shown where the hunt earns it.
  test "the orders' footer counts the SP a kill brings, as the guild does" do
    {view, session, _conn} = human(build_conn())
    view |> form("#travel-form", %{"place" => "hunt"}) |> render_submit()
    sp = ~s(#orders-footer [data-key="orders-sp"])
    assert has_element?(view, ~s(#{sp}[data-value="0"]))

    pin(session, 0.0)
    view |> element("#hunt-button") |> render_click()
    earned = stored(session).sp
    assert earned > 0
    assert has_element?(view, ~s(#{sp}[data-value="#{earned}"]))
  end

  # Rules §20: a character that knows no heal has none to order.
  test "once a heal is known, the orders also set when it mends, before the pull and in a fight" do
    {_view, session, conn} = human(build_conn())
    {:ok, view, _html} = ground(conn)
    refute has_element?(view, "#pull-share")

    Characters.mutate(session, &{%{&1 | skills: Map.put(&1.skills, "Self Heal", 1)}, :ok})
    {:ok, view, _html} = ground(conn)
    assert text(view, "#pull-share-value") == "below 70% HP"
    assert text(view, "#fight-share-value") == "never"

    slide(view, "pull", 1)
    slide(view, "fight", 1)

    assert %{heal_pull_at: 30, heal_fight_at: 30} = stored(session)
    assert text(view, "#pull-share-value") == "below 30% HP"
    assert text(view, "#fight-share-value") == "below 30% HP"
  end

  # Rules §20: a skill the orders leave unused is muted where it is listed, and its chip switched off.
  test "a switch leaves a skill unused and uses it again, a name with a colon in it too" do
    {_view, session, conn} = human(build_conn())
    skills = %{"Power Strike" => 1, "Curse: Poison" => 1, "Armor Mastery" => 1}
    Characters.mutate(session, &{%{&1 | skills: skills}, :ok})
    {:ok, view, _html} = ground(conn)

    assert has_element?(view, ~s(#use-power-strike[role=switch][aria-checked="true"]))
    assert has_element?(view, ~s(#skills-order .switches[role=group][aria-label="Use skills"]))
    refute has_element?(view, "#skills-order .stat-label")
    refute has_element?(view, "#use-armor-mastery")
    view |> element("#use-curse-poison") |> render_click()
    view |> element("#use-power-strike") |> render_click()

    assert stored(session).unused == ["Curse: Poison", "Power Strike"]
    assert has_element?(view, ~s(#use-power-strike[aria-checked="false"]))
    assert has_element?(view, ~s(#skills-order #use-curse-poison[aria-checked="false"]))
    refute has_element?(view, ".alert")

    {:ok, character, _html} = live(conn, ~p"/character")
    assert has_element?(character, "#skill-power-strike.locked", "Left unused, by your orders.")
    refute has_element?(character, "#orders")

    view |> element("#use-power-strike") |> render_click()
    assert stored(session).unused == ["Curse: Poison"]
    assert has_element?(view, ~s(#use-power-strike[aria-checked="true"]))
  end

  test "the footer's reset puts every order back as it started, disabled until one has moved" do
    {_view, session, conn} = human(build_conn())
    carry_potions(session)
    {:ok, view, _html} = ground(conn)
    reset = "#orders-footer button#orders-reset.link-button"
    assert has_element?(view, "#{reset}[disabled]", "Reset to Default")

    slide(view, "potion", 0)
    view |> element("#use-power-strike") |> render_click()
    assert has_element?(view, "#{reset}:not([disabled])")
    refute has_element?(view, "#orders-reset.btn")

    view |> element("#orders-reset") |> render_click()
    assert %{potion_at: 50, heal_pull_at: 70, heal_fight_at: 0, unused: []} = stored(session)
    assert has_element?(view, ~s(#potion-share[value="2"]))
    assert has_element?(view, ~s(#use-power-strike[aria-checked="true"]))
    assert has_element?(view, "#{reset}[disabled]")
    refute has_element?(view, ".alert")
  end
end
