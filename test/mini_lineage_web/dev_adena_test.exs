defmodule MiniLineageWeb.DevAdenaTest do
  @moduledoc """
  Typing `adena` in a debug build puts 10,000 in the purse, every time, so the Gatekeeper can be
  tried before anything earns Adena. Not async: a release is a flip of the debug build.
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
    |> render_submit(%{"name" => "Spender", "race_id" => "1", "path" => "fighter"})

    {view, session}
  end

  defp type(view, letters) do
    for <<letter <- letters>>, do: render_hook(view, "key", %{"key" => <<letter>>})
    render(view)
  end

  test "typing it fills the purse, and typing it again fills it again", %{conn: conn} do
    {view, session} = started(conn)
    assert has_element?(view, "#dev-keys[phx-hook=DevKeys]")

    assert type(view, "adena") =~ "10,000 Adena"
    assert stored(session).adena == 10_000

    type(view, "adena")
    assert stored(session).adena == 20_000
  end

  test "only the word itself, in order, does anything", %{conn: conn} do
    {view, session} = started(conn)

    type(view, "aden")
    type(view, "xadenx")
    type(view, "anade")
    render_hook(view, "key", %{"key" => "ArrowUp"})
    type(view, "dena")

    assert Characters.snapshot(session).adena == 0
  end

  test "a visitor is given nothing, having no purse" do
    session = Characters.new_session_id()
    on_exit(fn -> Characters.forget(session) end)

    {:ok, view, _html} =
      build_conn() |> init_test_session(%{"session_id" => session}) |> live(~p"/")

    refute has_element?(view, "#dev-keys")
    type(view, "adena")

    assert Characters.snapshot(session).adena == nil
  end

  test "a release never listens for it, nor answers it" do
    previous = Application.fetch_env!(:mini_lineage, :debug_build)
    Application.put_env(:mini_lineage, :debug_build, false)
    on_exit(fn -> Application.put_env(:mini_lineage, :debug_build, previous) end)

    {view, session} = started(build_conn())

    refute has_element?(view, "#dev-keys")
    type(view, "adena")
    assert stored(session).adena == 0

    # Nor does the action itself, whoever asks it.
    {result, _player} = Characters.mutate(session, &MiniLineage.Game.Actions.dev_adena/1)
    assert {:error, :invalid, _} = result
    assert stored(session).adena == 0
  end
end
