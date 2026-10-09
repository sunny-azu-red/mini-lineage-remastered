defmodule MiniLineageWeb.GatekeeperTest do
  @moduledoc """
  Rules §14 in the browser's own terms: the town's way to its Gatekeeper, the routes it lists and
  their fees, and the trip itself, which is paid for and written at once. Adena is arranged in the
  character's process, there being nothing yet to earn it with.
  """
  use MiniLineageWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import MiniLineage.DataCase, only: [stored: 1]

  alias MiniLineage.Characters

  # An Elf, standing in Elven Village with `adena` in its purse.
  defp elf(conn, adena) do
    session = Characters.new_session_id()
    on_exit(fn -> Characters.forget(session) end)
    conn = init_test_session(conn, %{"session_id" => session})
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> element("form[phx-submit=start]")
    |> render_submit(%{"name" => "Wanderer", "race_id" => "2", "path" => "fighter"})

    Characters.mutate(session, &{%{&1 | adena: adena}, :ok})
    {view, session, conn}
  end

  defp teleport(view, to), do: view |> form("#teleport-form", %{"to" => to}) |> render_submit()

  test "a character lands at its village's own address" do
    {view, _session, _conn} = elf(build_conn(), 0)

    assert_patch(view, "/elven-village")
    assert has_element?(view, "#screen[data-screen=town]")
  end

  test "the town's way out leads to its Gatekeeper, which is no trip at all" do
    {view, session, _conn} = elf(build_conn(), 0)

    view |> form("#travel-form", %{"place" => "gatekeeper"}) |> render_submit()

    assert_patch(view, "/elven-village/gatekeeper")
    assert has_element?(view, "#screen[data-screen=gatekeeper]")
    assert has_element?(view, "#sidebar")
    assert stored(session).location == "elven-village"
  end

  test "lists every route from here with its fee, and offers each one" do
    {_view, _session, conn} = elf(build_conn(), 0)
    {:ok, view, _html} = live(conn, ~p"/elven-village/gatekeeper")

    assert view |> element("#route-gludio") |> render() =~ "3,700"
    assert has_element?(view, ~s(#teleport-form option[value="gludio"]))
    refute has_element?(view, ~s(#teleport-form option[value="dark-elven-village"]))
  end

  test "its button says where it goes only once something is picked" do
    {_view, _session, conn} = elf(build_conn(), 0)
    {:ok, view, _html} = live(conn, ~p"/elven-village/gatekeeper")

    assert view |> element("#teleport-form button") |> render() =~ "Return"

    # A browser names the field that changed; the test client only when told to.
    view |> form("#teleport-form", %{"to" => "gludio"}) |> render_change(%{"_target" => ["to"]})
    assert view |> element("#teleport-form button") |> render() =~ "Teleport"
  end

  test "and its empty choice is the way back into town" do
    {_view, _session, conn} = elf(build_conn(), 0)
    {:ok, view, _html} = live(conn, ~p"/elven-village/gatekeeper")

    teleport(view, "")

    assert_patch(view, "/elven-village")
  end

  test "will not send a character who cannot pay" do
    {_view, session, conn} = elf(build_conn(), 3_699)
    {:ok, view, _html} = live(conn, ~p"/elven-village/gatekeeper")

    assert teleport(view, "gludio") =~ "cannot pay"
    assert stored(session).location == "elven-village"
    assert Characters.snapshot(session).adena == 3_699
  end

  test "goes nowhere a route does not, however the request is made" do
    {_view, session, conn} = elf(build_conn(), 100_000)
    {:ok, view, _html} = live(conn, ~p"/elven-village/gatekeeper")

    for to <- ["dark-elven-village", "dion", "elven-village", "atlantis"] do
      render_hook(view, "travel", %{"to" => to})
      assert Characters.snapshot(session).location == "elven-village", to
    end

    assert Characters.snapshot(session).adena == 100_000
  end

  test "takes the fee and moves the character, writing both before it says so" do
    {_view, session, conn} = elf(build_conn(), 10_000)
    {:ok, view, _html} = live(conn, ~p"/elven-village/gatekeeper")

    assert teleport(view, "gludio") =~ "3,700 Adena"
    assert_patch(view, "/gludio")
    assert %{location: "gludio", adena: 6_300} = stored(session)

    view |> form("#travel-form", %{"place" => "gatekeeper"}) |> render_submit()
    teleport(view, "dion")

    assert_patch(view, "/dion")
    assert %{location: "dion", adena: 2_200} = stored(session)
  end

  test "what a trip said stays for its arrival, and not for a walk to the Gatekeeper after it" do
    {_view, _session, conn} = elf(build_conn(), 10_000)
    {:ok, view, _html} = live(conn, ~p"/elven-village/gatekeeper")

    teleport(view, "gludio")
    assert has_element?(view, "#flash")

    view |> form("#travel-form", %{"place" => "gatekeeper"}) |> render_submit()
    refute has_element?(view, "#flash")
  end

  test "lists the towns not open yet, and will not send anybody to them" do
    {_view, session, conn} = elf(build_conn(), 100_000)
    Characters.mutate(session, &{%{&1 | location: "dion"}, :ok})
    {:ok, view, _html} = live(conn, ~p"/dion/gatekeeper")

    for slug <- ~w(giran giran-harbor) do
      assert view |> element("#route-#{slug}") |> render() =~ "not open yet"
      assert has_element?(view, ~s(#teleport-form option[value="#{slug}"][disabled]))
      assert render_hook(view, "travel", %{"to" => slug}) =~ "cannot send you there yet"
    end

    assert %{location: "dion", adena: 100_000} = Characters.snapshot(session)
  end

  test "a character asking for any other town is put back in the one it stands in" do
    {_view, _session, conn} = elf(build_conn(), 0)

    for path <- ["/gludio", "/orc-village/gatekeeper", "/"] do
      assert {:error, {:live_redirect, %{to: "/elven-village"}}} = live(conn, path), path
    end
  end

  test "a second tab follows the character to where it went" do
    {_view, _session, conn} = elf(build_conn(), 10_000)
    {:ok, other, _html} = live(conn, ~p"/elven-village")
    {:ok, view, _html} = live(conn, ~p"/elven-village/gatekeeper")

    teleport(view, "gludio")

    assert_patch(other, "/gludio")
  end

  test "a visitor has no town to stand in" do
    session = Characters.new_session_id()
    on_exit(fn -> Characters.forget(session) end)
    conn = init_test_session(build_conn(), %{"session_id" => session})

    assert {:error, {:live_redirect, %{to: "/"}}} = live(conn, ~p"/gludio")
  end
end
