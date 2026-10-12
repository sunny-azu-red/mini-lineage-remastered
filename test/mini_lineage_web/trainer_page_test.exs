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

  # A level 5 Human Fighter on Talking Island with `sp` to spend.
  defp human(conn, sp) do
    session = Characters.new_session_id()
    on_exit(fn -> Characters.forget(session) end)
    conn = init_test_session(conn, %{"session_id" => session})
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> element("form[phx-submit=start]")
    |> render_submit(%{"name" => "Pupil", "race_id" => "0", "path" => "fighter"})

    Characters.mutate(session, &{%{&1 | sp: sp, experience: Math.xp_for_level(5)}, :ok})
    {view, session, conn}
  end

  test "the home village leads to its trainer, whose lessons are the set's own" do
    {view, _session, _conn} = human(build_conn(), 100)

    assert has_element?(view, ~s(#travel-form option[value="trainer"]))
    view |> form("#travel-form", %{"place" => "trainer"}) |> render_submit()

    assert_patch(view, "/talking-island/trainer")
    assert has_element?(view, ~s(#lesson-power-strike-2[data-status="ready"]))
    refute has_element?(view, "#lesson-power-strike-2.locked")

    # A line waiting on the one before it is muted and not offered, though its level is reached.
    assert has_element?(view, ~s(#lesson-power-strike-3.locked[data-status="queued"]))
    refute has_element?(view, ~s(#learn-form option[value="Power Strike|3"]))
    # Above its level it is muted; another set's lines are not listed at all.
    assert has_element?(view, ~s(#lesson-power-strike-4.locked[data-status="later"]))
    refute has_element?(view, "#lesson-wind-strike-2")
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
    skill = ~s(#lessons button[phx-value-key="skill"])

    assert first.("power-strike-2")

    view |> element(skill) |> render_click()
    assert has_element?(view, ~s(#lessons th[aria-sort="ascending"]), "Skill")
    assert first.("mortal-blow-1")

    view |> element(skill) |> render_click()
    assert has_element?(view, ~s(#lessons th[aria-sort="descending"]), "Skill")
    assert first.("power-strike-9")

    view |> element(skill) |> render_click()
    refute has_element?(view, "#lessons th[aria-sort]")
    assert first.("power-strike-2")

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
    assert %{sp: 50, skills: %{"Power Strike" => 2}} = stored(session)
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

    assert has_element?(view, "#flash", "You do not have enough SP to learn that skill.")
    assert %{sp: 49, skills: %{"Power Strike" => 1}} = stored(session)
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
