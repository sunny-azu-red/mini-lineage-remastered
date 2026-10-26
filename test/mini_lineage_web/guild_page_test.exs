defmodule MiniLineageWeb.GuildPageTest do
  @moduledoc """
  Rules §25 in the browser's own terms: the home village's way to its guild, named for the set,
  what it can learn apart from what it knows, a lesson learned and written at once, and no guild
  anywhere but the character's own village.
  """
  use MiniLineageWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import MiniLineage.DataCase, only: [stored: 1]

  alias MiniLineage.Characters
  alias MiniLineage.Game.{Constants, Rules}
  alias MiniLineageWeb.Screens
  alias MiniLineage.Game.Math

  # A new Human Fighter on Talking Island.
  defp pupil(conn) do
    session = Characters.new_session_id()
    on_exit(fn -> Characters.forget(session) end)
    conn = init_test_session(conn, %{"session_id" => session})
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> element("form[phx-submit=start]")
    |> render_submit(%{"name" => "Pupil", "race_id" => "0", "path" => "fighter"})

    {view, session, conn}
  end

  # The same at level 5, with the Power Strike 1 it learned there and `sp` to spend.
  defp human(conn, sp) do
    {view, session, conn} = pupil(conn)
    level = Math.xp_for_level(5)
    skills = %{"Power Strike" => 1}
    Characters.mutate(session, &{%{&1 | sp: sp, experience: level, skills: skills}, :ok})
    {view, session, conn}
  end

  test "a new Fighter knows its weapon's skill, and its trainer offers another at level 1" do
    {_view, session, conn} = pupil(build_conn())
    {:ok, character, _html} = live(conn, ~p"/character")
    assert has_element?(character, "#skill-power-strike .skill", "Power Strike 1")

    {:ok, view, _html} = live(conn, ~p"/talking-island-village/warriors-guild")
    assert has_element?(view, "#screen h2", "Learned Skills")
    assert has_element?(view, ~s(#lesson-mortal-blow-1[data-status="ready"] td.sp), "50")
    refute has_element?(view, "#lesson-power-strike-1")

    Characters.mutate(session, &{%{&1 | sp: 50}, :ok})
    view |> form("#learn-form", %{"lesson" => "Mortal Blow|1"}) |> render_submit()

    assert has_element?(view, "#skill-mortal-blow .skill", "Mortal Blow 1")
    assert %{sp: 0, skills: %{"Power Strike" => 1, "Mortal Blow" => 1}} = stored(session)
  end

  test "the home village leads to its guild, whose lessons are the set's own" do
    {view, session, conn} = human(build_conn(), 100)

    assert has_element?(view, ~s(#travel-form option[value="guild"]), "📖 Warriors Guild")
    view |> form("#travel-form", %{"place" => "guild"}) |> render_submit()

    assert_patch(view, "/talking-island-village/warriors-guild")
    assert has_element?(view, "#screen h2", "Warriors Guild")

    assert has_element?(
             view,
             "#guild-intro",
             "Master Gwinter, Master Minia and Master Pintage teach"
           )

    assert has_element?(view, ~s(#lesson-power-strike-2[data-status="ready"]))
    refute has_element?(view, "#lesson-power-strike-2.locked")

    # Each skill shows its next line alone, and another set's lines are not listed at all.
    refute has_element?(view, "#lesson-power-strike-3")
    refute has_element?(view, ~s(#learn-form option[value="Power Strike|3"]))
    refute has_element?(view, "#lesson-wind-strike-2")

    # Once learned, the line after it shows, muted until its level is reached.
    Characters.mutate(session, &{%{&1 | skills: %{"Power Strike" => 2}}, :ok})
    {:ok, view, _html} = live(conn, ~p"/talking-island-village/warriors-guild")
    assert has_element?(view, ~s(#lesson-power-strike-3.locked[data-status="later"]))
    refute has_element?(view, "#lesson-power-strike-4")
  end

  test "what it knows is the Learned Skills panel, not a lesson" do
    {_view, _session, conn} = human(build_conn(), 100)
    {:ok, view, _html} = live(conn, ~p"/talking-island-village/warriors-guild")

    refute has_element?(view, "#lesson-power-strike-1")
    assert has_element?(view, "#skill-power-strike .skill", "Power Strike 1")
    assert view |> element("#skill-power-strike") |> render() =~ "💥 <span class=\"skill\">"
    # Each figure in the colour of what it is.
    assert has_element?(view, "#skill-power-strike .attack", "Power 25")
    assert has_element?(view, "#skill-power-strike .mp", "10 MP")
  end

  test "the lessons open on Level Req, a header turns them round, and the dropdown follows" do
    {_view, _session, conn} = human(build_conn(), 100)
    {:ok, view, _html} = live(conn, ~p"/talking-island-village/warriors-guild")
    # Within the Active shelf, past its heading; the dropdown's Active group the same.
    first = &has_element?(view, "#shelf-active tr.shelf + tr#lesson-#{&1}")
    last = &has_element?(view, "#shelf-active tr:last-child#lesson-#{&1}")

    offered =
      &has_element?(
        view,
        ~s{#learn-form optgroup[label="Active"] option:first-child[value="#{&1}"]}
      )

    header = &~s(#lessons button[phx-value-key="#{&1}"])

    # Level 1's two lines in the trainer's order, then Power Strike 2 at level 5.
    assert has_element?(view, ~s(#lessons th[aria-sort="ascending"]), "Level Req")
    assert first.("mortal-blow-1") and last.("power-strike-2")
    assert offered.("Mortal Blow|1")

    view |> element(header.("learn_at")) |> render_click()
    assert has_element?(view, ~s(#lessons th[aria-sort="descending"]), "Level Req")
    assert first.("power-strike-2") and last.("power-shot-1")
    assert offered.("Power Strike|2")

    view |> element(header.("learn_at")) |> render_click()
    assert has_element?(view, ~s(#lessons th[aria-sort="ascending"]), "Level Req")

    view |> element(header.("skill")) |> render_click()
    assert has_element?(view, ~s(#lessons th[aria-sort="ascending"]), "Skill")
    view |> element(header.("skill")) |> render_click()
    assert has_element?(view, ~s(#lessons th[aria-sort="descending"]), "Skill")
    assert first.("power-strike-2") and last.("mortal-blow-1")

    # A key the table does not offer is not stored.
    render_click(view, "sort", %{"table" => "lessons", "key" => "status"})
    assert has_element?(view, ~s(#lessons th[aria-sort="descending"]), "Skill")
  end

  test "an Active and a Passive shelf, as a trader's, until the masteries are learned out" do
    {_view, session, conn} = human(build_conn(), 100)
    {:ok, view, _html} = live(conn, ~p"/talking-island-village/warriors-guild")

    shelves = fn view ->
      view
      |> render()
      |> LazyHTML.from_fragment()
      |> LazyHTML.query("#lessons tbody")
      |> LazyHTML.attribute("id")
    end

    assert shelves.(view) == ~w(shelf-active shelf-passive)
    assert has_element?(view, "#shelf-active tr.shelf th", "Active")
    assert has_element?(view, "#shelf-passive tr.shelf th", "Passive")

    assert has_element?(
             view,
             ~s(#shelf-passive #lesson-armor-mastery-1[data-status="ready"] td.sp),
             "160"
           )

    assert has_element?(view, "#lesson-armor-mastery-1 td.name", "🪖 Armor Mastery 1")
    refute has_element?(view, "#shelf-active #lesson-armor-mastery-1")

    assert has_element?(
             view,
             ~s(#learn-form optgroup[label="Passive"] option[value="Armor Mastery|1"])
           )

    assert has_element?(
             view,
             ~s(#learn-form optgroup[label="Active"] option[value="Power Strike|2"])
           )

    # A sort turns each shelf round on its own; the mastery stays on its shelf.
    view |> element(~s(#lessons button[phx-value-key="learn_at"])) |> render_click()
    assert has_element?(view, "#shelf-passive tr.shelf + tr#lesson-armor-mastery-1")

    # Learned out, one shelf is left, with no heading and no group.
    masteries = %{"Armor Mastery" => 3, "Weapon Mastery" => 3, "Anti Magic" => 2}
    Characters.mutate(session, &{%{&1 | skills: Map.merge(&1.skills, masteries)}, :ok})
    {:ok, view, _html} = live(conn, ~p"/talking-island-village/warriors-guild")
    assert shelves.(view) == ~w(shelf-active)
    refute has_element?(view, "#lessons tr.shelf")
    refute has_element?(view, "#learn-form optgroup")
    assert has_element?(view, "#skill-armor-mastery .skill", "Armor Mastery 3")
  end

  test "Learned Skills lists the active skills first and the masteries last, each by name" do
    {_view, session, conn} = human(build_conn(), 100)
    masteries = %{"Armor Mastery" => 1, "Anti Magic" => 1}
    Characters.mutate(session, &{%{&1 | skills: Map.merge(&1.skills, masteries)}, :ok})
    {:ok, view, _html} = live(conn, ~p"/talking-island-village/warriors-guild")

    rows =
      view
      |> render()
      |> LazyHTML.from_fragment()
      |> LazyHTML.query("[id^=skill-]")
      |> LazyHTML.attribute("id")

    assert rows == ~w(skill-power-strike skill-anti-magic skill-armor-mastery)
  end

  test "the lessons do not remember their sort, so a kept one is not read back" do
    {_view, _session, conn} = human(build_conn(), 100)
    conn = put_req_cookie(conn, MiniLineageWeb.Kept.cookie(), "table%3Alessons=sp%3Adesc")
    {:ok, view, _html} = live(conn, ~p"/talking-island-village/warriors-guild")

    assert has_element?(view, ~s(#lessons th[aria-sort="ascending"]), "Level Req")
    refute has_element?(view, ~s(#lessons th[aria-sort="descending"]))
    refute has_element?(view, "#lessons thead[phx-hook]")
  end

  test "every skill a set learns has an emoji of its own, no other effect's, a heal 💚 and an aura's the one Buffs shows" do
    for set <- Rules.sets() do
      icons =
        for(%{skill: skill} <- Rules.lessons(set.name), uniq: true, do: skill)
        |> Enum.map(&Screens.skill_icon/1)

      assert Enum.uniq(icons) == icons, set.name
    end

    for {name, %{kind: :heal}} <- Rules.skills(), do: assert(Screens.skill_icon(name) == "💚")

    # Nor is a skill's emoji another effect's on the same Buffs & Debuffs panel, or a lineage's.
    taken =
      ~w(combat resting night shadow_sense mother_tree regenerating ghost)a
      |> Enum.map(&Constants.aura(&1).emoji)
      |> Enum.concat(Enum.map(Constants.races(), & &1.emoji))

    for name <- Map.keys(Rules.skills()),
        Rules.skill(name).kind not in [:aura, :rest],
        do: refute(Screens.skill_icon(name) in taken, name)

    assert Screens.skill_icon("Defense Aura") == "🛡️"
    assert Screens.skill_icon("Relax") == "🧘"
  end

  test "SP is paid like Adena: a line in reach but beyond the purse is still offered" do
    {_view, _session, conn} = human(build_conn(), 49)
    {:ok, view, _html} = live(conn, ~p"/talking-island-village/warriors-guild")

    refute has_element?(view, "#lesson-power-strike-2.locked")

    assert has_element?(
             view,
             ~s(#learn-form option[value="Power Strike|2"]),
             "Pick 💥 Power Strike 2"
           )

    refute has_element?(view, "#nothing-to-learn")
  end

  test "nothing in reach names the level the next line waits on" do
    {_view, session, conn} = human(build_conn(), 0)
    level = Math.xp_for_level(5)

    known = %{
      "Power Strike" => 2,
      "Mortal Blow" => 2,
      "Power Shot" => 2,
      "Armor Mastery" => 1,
      "Weapon Mastery" => 1,
      "Anti Magic" => 1
    }

    Characters.mutate(session, &{%{&1 | experience: level, skills: known}, :ok})
    {:ok, view, _html} = live(conn, ~p"/talking-island-village/warriors-guild")

    assert has_element?(view, "#lessons")
    assert has_element?(view, "#nothing-to-learn", "until Level 10.")
    refute has_element?(view, "#learned-out")
  end

  test "a guild learned out says so, with no table left to head" do
    {_view, session, conn} = human(build_conn(), 0)
    known = Rules.lessons("Human Fighter") |> Map.new(&{&1.skill, &1.level})
    Characters.mutate(session, &{%{&1 | skills: Map.merge(&1.skills, known)}, :ok})
    {:ok, view, _html} = live(conn, ~p"/talking-island-village/warriors-guild")

    assert has_element?(view, "#learned-out", "They have taught you all they can for now.")
    refute has_element?(view, "#lessons")
    refute has_element?(view, "#nothing-to-learn")
    assert has_element?(view, "#learn-form button", "Return")
  end

  test "a lesson is paid in SP and known at once" do
    {_view, session, conn} = human(build_conn(), 100)
    {:ok, view, _html} = live(conn, ~p"/talking-island-village/warriors-guild")

    view |> form("#learn-form", %{"lesson" => "Power Strike|2"}) |> render_submit()

    assert has_element?(view, "#flash .skill", "Power Strike 2")
    refute has_element?(view, "#lesson-power-strike-2")
    assert has_element?(view, "#skill-power-strike .skill", "Power Strike 2")
    assert %{sp: 0, skills: %{"Power Strike" => 2}} = stored(session)
  end

  test "the SP counts down as it is spent, under the panel's own icon for what is learned" do
    {_view, _session, conn} = human(build_conn(), 100)
    {:ok, view, _html} = live(conn, ~p"/talking-island-village/warriors-guild")

    assert has_element?(
             view,
             ~s(#guild-intro[phx-hook="AnimatedValues"] [data-key="guild-sp"])
           )

    assert has_element?(view, "#screen h2", "🎓 Learned Skills")
    assert has_element?(view, ~s(#learned-skills[phx-hook="Panel"] > h2 > button.panel-toggle))
    refute has_element?(view, "#screen > .panel:first-child .panel-toggle")
  end

  test "a lesson learned leaves the button going back, as the dropdown falls back to it" do
    {_view, _session, conn} = human(build_conn(), 100)
    {:ok, view, _html} = live(conn, ~p"/talking-island-village/warriors-guild")
    lesson = %{"lesson" => "Power Strike|2"}

    view |> form("#learn-form", lesson) |> render_change(%{"_target" => ["lesson"]})
    assert has_element?(view, "#learn-form button", "📖 Learn")

    view |> form("#learn-form", lesson) |> render_submit()
    assert has_element?(view, "#learn-form button", "Return")
    assert has_element?(view, ~s(#learn-form option[value=""][selected]))
  end

  test "a lesson beyond the purse is refused in plain words" do
    {_view, session, conn} = human(build_conn(), 49)
    {:ok, view, _html} = live(conn, ~p"/talking-island-village/warriors-guild")

    view |> form("#learn-form", %{"lesson" => "Power Strike|2"}) |> render_submit()

    assert has_element?(view, "#flash", "You do not have enough SP to learn this skill.")
    assert %{sp: 49, skills: %{"Power Strike" => 1}} = stored(session)
  end

  test "a line needing a weapon says so after its name, and a spell says nothing" do
    {_view, session, conn} = human(build_conn(), 100)
    {:ok, view, _html} = live(conn, ~p"/talking-island-village/warriors-guild")

    assert has_element?(view, "#lesson-power-strike-2 td.name .muted", "Needs a sword")
    assert has_element?(view, "#lesson-mortal-blow-1 td.name .muted", "Needs a dagger")
    assert has_element?(view, "#lesson-power-shot-1 td.name .muted", "Needs a bow")
    refute has_element?(view, "#lesson-armor-mastery-1 td.name .muted")

    Characters.mutate(session, &{%{&1 | path: :mystic, skills: %{"Wind Strike" => 1}}, :ok})
    {:ok, view, _html} = live(conn, ~p"/talking-island-village/mystics-guild")

    assert has_element?(view, "#lesson-wind-strike-2")
    refute has_element?(view, "#lesson-wind-strike-2 td.name .muted")
  end

  test "a toggle says what it costs to light and what it drains after" do
    {_view, session, conn} = pupil(build_conn())
    Characters.mutate(session, &{%{&1 | skills: %{"Soul Cry" => 1}}, :ok})
    {:ok, view, _html} = live(conn, ~p"/character")

    assert view |> element("#skill-soul-cry") |> render() =~
             ~r/\+4\.5 P\. Atk\.<\/span>\sfor .*2 MP.*then.*3 MP.*every 3s/s
  end

  test "a learned skill the weapon in hand cannot use is muted, and says what it needs" do
    {_view, session, conn} = human(build_conn(), 100)
    Characters.mutate(session, &{%{&1 | skills: Map.put(&1.skills, "Mortal Blow", 1)}, :ok})
    {:ok, view, _html} = live(conn, ~p"/talking-island-village/warriors-guild")

    # The kit's Squire's Sword is in hand, the Squire's Dagger carried.
    assert has_element?(view, "#skill-mortal-blow.locked", "Needs a dagger equipped.")
    refute has_element?(view, "#skill-power-strike.locked")
    refute has_element?(view, "#skill-power-strike", "Needs")

    dagger = Enum.find(Characters.snapshot(session).items, &(&1.name == "Squire's Dagger"))
    Characters.mutate(session, &MiniLineage.Game.Actions.equip(&1, dagger.id))
    {:ok, view, _html} = live(conn, ~p"/character")

    refute has_element?(view, "#skill-mortal-blow.locked")
    assert has_element?(view, "#skill-power-strike.locked", "Needs a sword equipped.")
  end

  test "a Mystic of another race learns in its own village's guild, from its own trainers" do
    session = Characters.new_session_id()
    on_exit(fn -> Characters.forget(session) end)
    conn = init_test_session(build_conn(), %{"session_id" => session})
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> element("form[phx-submit=start]")
    |> render_submit(%{"name" => "Pupil", "race_id" => "1", "path" => "mystic"})

    {:ok, view, _html} = live(conn, ~p"/orc-village/mystics-guild")
    assert has_element?(view, "#screen h2", "Mystics Guild")

    assert has_element?(
             view,
             "#guild-intro",
             "Seer Tanapi and Seer Livina teach their own here in 🏕️ Orc Village"
           )
  end

  test "a village with two guilds sends a run to its own, at the guild's own name" do
    {_view, session, conn} = human(build_conn(), 0)
    Characters.mutate(session, &{%{&1 | path: :mystic}, :ok})

    {:error, {:live_redirect, %{to: "/talking-island-village/mystics-guild"}}} =
      live(conn, ~p"/talking-island-village/warriors-guild")

    {:ok, view, _html} = live(conn, ~p"/talking-island-village/mystics-guild")
    assert has_element?(view, "#screen h2", "Mystics Guild")
  end

  test "no guild away from the home village, even in another village" do
    {_view, session, conn} = human(build_conn(), 0)

    {:error, {:live_redirect, %{to: "/talking-island-village"}}} =
      live(conn, ~p"/elven-village/evas-sanctuary")

    Characters.mutate(session, &{%{&1 | location: "elven-village"}, :ok})
    {:ok, view, _html} = live(conn, ~p"/elven-village")
    refute has_element?(view, ~s(#travel-form option[value="guild"]))
    assert has_element?(view, ~s(#travel-form option[value="trader"]))

    # Standing in the Elves' village is not enough: its trainers teach Elves.
    {:error, {:live_redirect, %{to: "/elven-village"}}} =
      live(conn, ~p"/elven-village/evas-sanctuary")
  end
end
