defmodule MiniLineageWeb.QuitTest do
  @moduledoc """
  The temporary Quit, Ctrl+C twice, for trying every race and path from one browser: it deletes the
  character and sends the browser back to game start. Debug builds only; a release never listens.
  The town's dropdown is left to the game.
  """
  use MiniLineageWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import MiniLineage.DataCase, only: [stored: 1]

  alias MiniLineage.Characters

  defp started(conn) do
    session = Characters.new_session_id()
    on_exit(fn -> Characters.forget(session) end)
    {:ok, view, _html} = conn |> init_test_session(%{"session_id" => session}) |> live(~p"/")

    view
    |> element("form[phx-submit=start]")
    |> render_submit(%{"name" => "Quitter", "race_id" => "2", "path" => "mystic"})

    {view, session}
  end

  defp press(view, keys), do: for(key <- keys, do: render_hook(view, "key", %{"key" => key}))

  test "Ctrl+C twice deletes the character and goes back to game start", %{conn: conn} do
    {view, session} = started(conn)
    assert stored(session).name == "Quitter"

    press(view, ~w(ctrl+c ctrl+c))

    assert_patch(view, "/")
    assert render(view) =~ "A New Bloodline Rises"
    assert stored(session) == nil
    refute Characters.snapshot(session).race_id
  end

  test "once, or twice with anything between, does nothing", %{conn: conn} do
    {view, session} = started(conn)

    press(view, ~w(ctrl+c))
    assert stored(session).name == "Quitter"

    press(view, ~w(x ctrl+c d ctrl+c))
    assert stored(session).name == "Quitter"
  end

  test "and the same browser can start another at once", %{conn: conn} do
    {view, session} = started(conn)
    press(view, ~w(ctrl+c ctrl+c))

    view
    |> element("form[phx-submit=start]")
    |> render_submit(%{"name" => "Again", "race_id" => "1", "path" => "fighter"})

    assert stored(session).name == "Again"
    assert render(view) =~ "Orc Village"
  end

  test "the town's dropdown offers the game's places and nothing else", %{conn: conn} do
    {view, _session} = started(conn)

    options = view |> element("#travel-form select") |> render()
    assert options =~ ~s(value="gatekeeper")
    refute options =~ "Quit"
  end

  test "is never answered in a release" do
    previous = Application.fetch_env!(:mini_lineage, :debug_build)
    Application.put_env(:mini_lineage, :debug_build, false)
    on_exit(fn -> Application.put_env(:mini_lineage, :debug_build, previous) end)

    {view, session} = started(build_conn())

    refute has_element?(view, "#dev-keys")
    press(view, ~w(ctrl+c ctrl+c))
    assert stored(session).name == "Quitter"
  end
end
