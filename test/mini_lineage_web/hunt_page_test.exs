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
  alias MiniLineage.Game.Rng

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
    refute has_element?(view, "#fight-log")
    assert has_element?(view, "#effects [data-effect-id=combat]")
    assert stored(session).combat == "engaged"

    view |> element("#hunt-button") |> render_click()

    assert has_element?(view, "#fight-log li", "You meet")
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
    assert has_element?(view, "#fight-log li", "You meet")
    assert has_element?(view, "#fight-log li", "Round 1:")
    assert has_element?(view, "#fight-log li", "HP, you at")
    assert has_element?(view, "#screen[data-screen=hunt]")
    player = stored(session)
    assert player.experience > 0 and player.sp > 0 and player.adena > 0
  end

  test "a death ends the run, keeps its row, and sends the browser back to game start" do
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

    assert_patch(view, "/")
    assert has_element?(view, "#flash", "your road ends here")
    assert has_element?(view, "#screen[data-screen=start]")
    assert %{dead: true, session_id: nil} = Repo.get!(Record, id)
  end
end
