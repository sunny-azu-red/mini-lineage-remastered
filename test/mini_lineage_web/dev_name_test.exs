defmodule MiniLineageWeb.DevNameTest do
  @moduledoc """
  A debug build writes a name in on game start, so trying another race takes one click. Which name
  is drawn is never asserted, only that there is one. Not async: a release is a flip of the debug
  build.
  """
  use MiniLineageWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import MiniLineage.DataCase, only: [stored: 1]

  alias MiniLineage.Characters

  defp visit(conn) do
    session = Characters.new_session_id()
    on_exit(fn -> Characters.forget(session) end)
    {:ok, view, _html} = conn |> init_test_session(%{"session_id" => session}) |> live(~p"/")
    {view, session}
  end

  defp name(view) do
    view
    |> element(~s(input[name="name"]))
    |> render()
    |> then(&Regex.run(~r/value="([^"]*)"/, &1))
  end

  test "game start comes with a name, and a start needs nothing else", %{conn: conn} do
    {view, session} = visit(conn)
    assert [_, drawn] = name(view)
    assert drawn =~ ~r/^\w+$/

    view
    |> form("form[phx-submit=start]", %{"race_id" => "3", "path" => "mystic"})
    |> render_submit()

    assert stored(session).name == drawn
  end

  test "a release leaves the name to the player" do
    previous = Application.fetch_env!(:mini_lineage, :debug_build)
    Application.put_env(:mini_lineage, :debug_build, false)
    on_exit(fn -> Application.put_env(:mini_lineage, :debug_build, previous) end)

    {view, _session} = visit(build_conn())

    assert name(view) == nil
  end
end
