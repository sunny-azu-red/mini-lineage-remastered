defmodule MiniLineageWeb.QuitTest do
  @moduledoc """
  The temporary Quit button, for trying every race and path from one browser: it deletes the
  character and sends the browser back to game start. Debug builds only; a release never draws it.
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

  test "deletes the character and goes back to game start", %{conn: conn} do
    {view, session} = started(conn)
    assert stored(session).name == "Quitter"

    view |> element("#quit") |> render_click()

    assert_patch(view, "/")
    assert render(view) =~ "A New Bloodline Rises"
    assert stored(session) == nil
    refute Characters.snapshot(session).race_id
  end

  test "and the same browser can start another at once", %{conn: conn} do
    {view, session} = started(conn)
    view |> element("#quit") |> render_click()

    view
    |> element("form[phx-submit=start]")
    |> render_submit(%{"name" => "Again", "race_id" => "1", "path" => "fighter"})

    assert stored(session).name == "Again"
    assert render(view) =~ "Orc Village"
  end

  test "is never drawn, nor answered, in a release" do
    previous = Application.fetch_env!(:mini_lineage, :debug_build)
    Application.put_env(:mini_lineage, :debug_build, false)
    on_exit(fn -> Application.put_env(:mini_lineage, :debug_build, previous) end)

    {view, session} = started(build_conn())

    refute has_element?(view, "#quit")
    render_hook(view, "quit", %{})
    assert stored(session).name == "Quitter"
  end
end
