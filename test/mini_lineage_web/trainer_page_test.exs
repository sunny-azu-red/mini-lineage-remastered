defmodule MiniLineageWeb.TrainerPageTest do
  @moduledoc """
  Rules §25 in the browser's own terms: the home village's way to its trainer, a lesson learned and
  written at once, and no trainer anywhere but the character's own village.
  """
  use MiniLineageWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import MiniLineage.DataCase, only: [stored: 1]

  alias MiniLineage.Characters
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
    {view, _session, _conn} = human(build_conn(), 0)

    assert has_element?(view, ~s(#travel-form option[value="trainer"]))
    view |> form("#travel-form", %{"place" => "trainer"}) |> render_submit()

    assert_patch(view, "/talking-island/trainer")
    assert has_element?(view, ~s(#lesson-power-strike-2[data-status="ready"]))
    assert has_element?(view, ~s(#lesson-power-strike-4[data-status="later"]))
    refute has_element?(view, "#lesson-wind-strike-2")
  end

  test "a lesson is paid in SP and known at once" do
    {_view, session, conn} = human(build_conn(), 100)
    {:ok, view, _html} = live(conn, ~p"/talking-island/trainer")

    view |> form("#learn-form", %{"lesson" => "Power Strike|2"}) |> render_submit()

    assert has_element?(view, "#flash", "Power Strike level 2")
    assert has_element?(view, ~s(#lesson-power-strike-2[data-status="known"]))
    assert %{sp: 50, skills: %{"Power Strike" => 2}} = stored(session)
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
