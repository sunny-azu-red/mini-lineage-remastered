defmodule MiniLineageWeb.DevFrailTest do
  @moduledoc """
  Typing `frail` in a debug build leaves the character 1 HP, so a browser suite can reach a death
  (rules §21) without pinning dice it cannot reach. Not async: a release is a flip of the debug build.
  """
  use MiniLineageWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  alias MiniLineage.Characters
  alias MiniLineage.Game.Actions

  defp started(conn) do
    session = Characters.new_session_id()
    on_exit(fn -> Characters.forget(session) end)
    {:ok, view, _html} = conn |> init_test_session(%{"session_id" => session}) |> live(~p"/")

    view
    |> element("form[phx-submit=start]")
    |> render_submit(%{"name" => "Frail", "race_id" => "1", "path" => "fighter"})

    {view, session}
  end

  defp type(view, letters) do
    for <<letter <- letters>>, do: render_hook(view, "key", %{"key" => <<letter>>})
    render(view)
  end

  test "typing it leaves 1 HP", %{conn: conn} do
    {view, session} = started(conn)

    # Read from the process: HP rides along with the next write rather than being written now.
    assert type(view, "frail") =~ "leaves you"
    assert Characters.snapshot(session).health == 1
  end

  test "a release never listens for it, nor answers it" do
    previous = Application.fetch_env!(:mini_lineage, :debug_build)
    Application.put_env(:mini_lineage, :debug_build, false)
    on_exit(fn -> Application.put_env(:mini_lineage, :debug_build, previous) end)

    {view, session} = started(build_conn())
    before = Characters.snapshot(session)

    type(view, "frail")
    assert Characters.snapshot(session).health == before.health

    {result, player} = Characters.mutate(session, &Actions.dev_frail/1)
    assert {:error, :invalid, _} = result
    assert player.health == before.health
  end
end
