defmodule MiniLineageWeb.DevSpTest do
  @moduledoc """
  Typing `sp` in a debug build hands over 10,000 SP, every time, so the trainer can be tried before
  the hunt has earned any. Not async: a release is a flip of the debug build.
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
    |> render_submit(%{"name" => "Learner", "race_id" => "1", "path" => "fighter"})

    {view, session}
  end

  defp type(view, letters) do
    for <<letter <- letters>>, do: render_hook(view, "key", %{"key" => <<letter>>})
    render(view)
  end

  test "typing it hands over SP, and typing it again hands over more", %{conn: conn} do
    {view, session} = started(conn)

    assert type(view, "sp") =~ "10,000 SP"
    assert stored(session).sp == 10_000

    type(view, "sp")
    assert stored(session).sp == 20_000
  end

  test "only the word itself, in order, does anything", %{conn: conn} do
    {view, session} = started(conn)

    type(view, "ps")
    type(view, "sxp")
    assert Characters.snapshot(session).sp == 0
  end

  test "a release never listens for it, nor answers it" do
    previous = Application.fetch_env!(:mini_lineage, :debug_build)
    Application.put_env(:mini_lineage, :debug_build, false)
    on_exit(fn -> Application.put_env(:mini_lineage, :debug_build, previous) end)

    {view, session} = started(build_conn())

    type(view, "sp")
    assert stored(session).sp == 0

    {result, _player} = Characters.mutate(session, &MiniLineage.Game.Actions.dev_sp/1)
    assert {:error, :invalid, _} = result
    assert stored(session).sp == 0
  end
end
