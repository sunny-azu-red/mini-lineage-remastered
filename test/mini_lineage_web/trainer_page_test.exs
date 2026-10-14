defmodule MiniLineageWeb.TrainerPageTest do
  @moduledoc """
  Rules §25 in the browser's own terms: the home village's way to its trainer, what it can learn
  apart from what it knows, a lesson learned and written at once, and no trainer anywhere but the
  character's own village.
  """
  use MiniLineageWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import MiniLineage.DataCase, only: [stored: 1]

  alias MiniLineage.Characters
  alias MiniLineage.Game.Rules
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
    refute has_element?(character, "#no-skills")
    assert has_element?(character, "#skill-power-strike .skill", "Power Strike 1")

    {:ok, view, _html} = live(conn, ~p"/talking-island/trainer")
    assert has_element?(view, "#screen h2", "Learned Skills")
    assert has_element?(view, ~s(#lesson-mortal-blow-1[data-status="ready"] td.sp), "50")
    refute has_element?(view, "#lesson-power-strike-1")

    Characters.mutate(session, &{%{&1 | sp: 50}, :ok})
    view |> form("#learn-form", %{"lesson" => "Mortal Blow|1"}) |> render_submit()

    assert has_element?(view, "#skill-mortal-blow .skill", "Mortal Blow 1")
    assert %{sp: 0, skills: %{"Power Strike" => 1, "Mortal Blow" => 1}} = stored(session)
  end

  test "the home village leads to its trainer, whose lessons are the set's own" do
    {view, session, conn} = human(build_conn(), 100)

    assert has_element?(view, ~s(#travel-form option[value="trainer"]))
    view |> form("#travel-form", %{"place" => "trainer"}) |> render_submit()

    assert_patch(view, "/talking-island/trainer")
    assert has_element?(view, ~s(#lesson-power-strike-2[data-status="ready"]))
    refute has_element?(view, "#lesson-power-strike-2.locked")

    # Each skill shows its next line alone, and another set's lines are not listed at all.
    refute has_element?(view, "#lesson-power-strike-3")
    refute has_element?(view, ~s(#learn-form option[value="Power Strike|3"]))
    refute has_element?(view, "#lesson-wind-strike-2")

    # Once learned, the line after it shows, muted until its level is reached.
    Characters.mutate(session, &{%{&1 | skills: %{"Power Strike" => 2}}, :ok})
    {:ok, view, _html} = live(conn, ~p"/talking-island/trainer")
    assert has_element?(view, ~s(#lesson-power-strike-3.locked[data-status="later"]))
    refute has_element?(view, "#lesson-power-strike-4")
  end

  test "what it knows is the Learned Skills panel, not a lesson" do
    {_view, _session, conn} = human(build_conn(), 100)
    {:ok, view, _html} = live(conn, ~p"/talking-island/trainer")

    refute has_element?(view, "#lesson-power-strike-1")
    assert has_element?(view, "#skill-power-strike .skill", "Power Strike 1")
    assert view |> element("#skill-power-strike") |> render() =~ "💥 <span class=\"skill\">"
    # Each figure in the colour of what it is.
    assert has_element?(view, "#skill-power-strike .attack", "Power 25")
    assert has_element?(view, "#skill-power-strike .mp", "10 MP")
  end

  test "a header sorts the lessons up, then down, then back to the trainer's own order" do
    {_view, _session, conn} = human(build_conn(), 100)
    {:ok, view, _html} = live(conn, ~p"/talking-island/trainer")
    first = &has_element?(view, "#lessons tbody tr:first-child#lesson-#{&1}")
    last = &has_element?(view, "#lessons tbody tr:last-child#lesson-#{&1}")
    skill = ~s(#lessons button[phx-value-key="skill"])

    assert first.("power-strike-2")

    view |> element(skill) |> render_click()
    assert has_element?(view, ~s(#lessons th[aria-sort="ascending"]), "Skill")
    assert first.("mortal-blow-1")

    view |> element(skill) |> render_click()
    assert has_element?(view, ~s(#lessons th[aria-sort="descending"]), "Skill")
    assert first.("power-strike-2") and last.("mortal-blow-1")

    view |> element(skill) |> render_click()
    refute has_element?(view, "#lessons th[aria-sort]")
    assert first.("power-strike-2") and last.("power-shot-1")

    # A key the table does not offer is not stored.
    render_click(view, "sort", %{"table" => "lessons", "key" => "status"})
    refute has_element?(view, "#lessons th[aria-sort]")
  end

  test "the lessons do not remember their sort, so a kept one is not read back" do
    {_view, _session, conn} = human(build_conn(), 100)
    conn = put_connect_params(conn, %{"tables" => %{"lessons" => "sp:desc"}})
    {:ok, view, _html} = live(conn, ~p"/talking-island/trainer")

    refute has_element?(view, "#lessons th[aria-sort]")
    refute has_element?(view, "#lessons thead[phx-hook]")
  end

  test "every skill has an emoji of its own, an aura's the one Buffs shows" do
    icons = Enum.map(Map.keys(Rules.skills()), &Screens.skill_icon/1)
    assert Enum.uniq(icons) == icons

    assert Screens.skill_icon("Defense Aura") == "🛡️"
    assert Screens.skill_icon("Relax") == "🧘"
  end

  test "SP is paid like Adena: a line in reach but beyond the purse is still offered" do
    {_view, _session, conn} = human(build_conn(), 49)
    {:ok, view, _html} = live(conn, ~p"/talking-island/trainer")

    refute has_element?(view, "#lesson-power-strike-2.locked")

    assert has_element?(
             view,
             ~s(#learn-form option[value="Power Strike|2"]),
             "Pick 💥 Power Strike 2"
           )

    refute has_element?(view, "#nothing-to-learn")
  end

  test "a lesson is paid in SP and known at once" do
    {_view, session, conn} = human(build_conn(), 100)
    {:ok, view, _html} = live(conn, ~p"/talking-island/trainer")

    view |> form("#learn-form", %{"lesson" => "Power Strike|2"}) |> render_submit()

    assert has_element?(view, "#flash .skill", "Power Strike 2")
    refute has_element?(view, "#lesson-power-strike-2")
    assert has_element?(view, "#skill-power-strike .skill", "Power Strike 2")
    assert %{sp: 0, skills: %{"Power Strike" => 2}} = stored(session)
  end

  test "the SP counts down as it is spent, under the panel's own icon for what is learned" do
    {_view, _session, conn} = human(build_conn(), 100)
    {:ok, view, _html} = live(conn, ~p"/talking-island/trainer")

    assert has_element?(
             view,
             ~s(#trainer-intro[phx-hook="AnimatedValues"] [data-key="trainer-sp"])
           )

    assert has_element?(view, "#screen h2", "🎓 Learned Skills")
  end

  test "a lesson learned leaves the button going back, as the dropdown falls back to it" do
    {_view, _session, conn} = human(build_conn(), 100)
    {:ok, view, _html} = live(conn, ~p"/talking-island/trainer")
    lesson = %{"lesson" => "Power Strike|2"}

    view |> form("#learn-form", lesson) |> render_change(%{"_target" => ["lesson"]})
    assert has_element?(view, "#learn-form button", "🎓 Learn")

    view |> form("#learn-form", lesson) |> render_submit()
    assert has_element?(view, "#learn-form button", "Return")
    assert has_element?(view, ~s(#learn-form option[value=""][selected]))
  end

  test "a lesson beyond the purse is refused in plain words" do
    {_view, session, conn} = human(build_conn(), 49)
    {:ok, view, _html} = live(conn, ~p"/talking-island/trainer")

    view |> form("#learn-form", %{"lesson" => "Power Strike|2"}) |> render_submit()

    assert has_element?(view, "#flash", "You do not have enough SP to learn this skill.")
    assert %{sp: 49, skills: %{"Power Strike" => 1}} = stored(session)
  end

  test "each line names the weapon it needs, and a set of spells has no such column" do
    {_view, session, conn} = human(build_conn(), 100)
    {:ok, view, _html} = live(conn, ~p"/talking-island/trainer")

    assert has_element?(view, "#lessons th", "Weapon")
    assert has_element?(view, "#lesson-power-strike-2 td", "Sword")
    assert has_element?(view, "#lesson-mortal-blow-1 td", "Dagger")
    assert has_element?(view, "#lesson-power-shot-1 td", "Bow")

    Characters.mutate(session, &{%{&1 | path: :mystic, skills: %{"Wind Strike" => 1}}, :ok})
    {:ok, view, _html} = live(conn, ~p"/talking-island/trainer")

    assert has_element?(view, "#lesson-wind-strike-2")
    refute has_element?(view, "#lessons th", "Weapon")
  end

  test "a toggle says what it costs to light and what it drains after" do
    {_view, session, conn} = pupil(build_conn())
    Characters.mutate(session, &{%{&1 | skills: %{"Soul Cry" => 1}}, :ok})
    {:ok, view, _html} = live(conn, ~p"/character")

    assert view |> element("#skill-soul-cry") |> render() =~
             ~r/P\.Atk \+4\.5.*2 MP.*then.*3 MP.*every 3 seconds/s
  end

  test "a learned skill the weapon in hand cannot use is muted, and says what it needs" do
    {_view, session, conn} = human(build_conn(), 100)
    Characters.mutate(session, &{%{&1 | skills: Map.put(&1.skills, "Mortal Blow", 1)}, :ok})
    {:ok, view, _html} = live(conn, ~p"/talking-island/trainer")

    # The kit's Squire's Sword is in hand, the Dagger carried.
    assert has_element?(view, "#skill-mortal-blow.locked", "Needs a dagger.")
    refute has_element?(view, "#skill-power-strike.locked")
    refute has_element?(view, "#skill-power-strike", "Needs")

    dagger = Enum.find(Characters.snapshot(session).items, &(&1.name == "Dagger"))
    Characters.mutate(session, &MiniLineage.Game.Actions.equip(&1, dagger.id))
    {:ok, view, _html} = live(conn, ~p"/character")

    refute has_element?(view, "#skill-mortal-blow.locked")
    assert has_element?(view, "#skill-power-strike.locked", "Needs a sword.")
  end

  test "no trainer away from the home village, even in another village" do
    {_view, session, conn} = human(build_conn(), 0)

    {:error, {:live_redirect, %{to: "/talking-island"}}} = live(conn, ~p"/elven-village/trainer")

    Characters.mutate(session, &{%{&1 | location: "elven-village"}, :ok})
    {:ok, view, _html} = live(conn, ~p"/elven-village")
    refute has_element?(view, ~s(#travel-form option[value="trainer"]))
    assert has_element?(view, ~s(#travel-form option[value="trader"]))

    # Standing in the Elves' village is not enough: its trainers teach Elves.
    {:error, {:live_redirect, %{to: "/elven-village"}}} = live(conn, ~p"/elven-village/trainer")
  end
end
