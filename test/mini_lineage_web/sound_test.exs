defmodule MiniLineageWeb.SoundTest do
  @moduledoc """
  The two sounds the game plays: the new-game fanfare, pushed by the server when a character is
  made, and the toggle's own chime, which the browser plays without asking anybody.
  """
  use MiniLineageWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias MiniLineage.Characters

  defp visitor(conn) do
    session = Characters.new_session_id()
    on_exit(fn -> Characters.forget(session) end)
    {:ok, view, _html} = conn |> init_test_session(%{"session_id" => session}) |> live(~p"/")

    view
  end

  test "making a character plays the new-game fanfare", %{conn: conn} do
    view = visitor(conn)

    view
    |> element("form[phx-submit=start]")
    |> render_submit(%{"name" => "Heard", "race_id" => "0", "path" => "fighter"})

    assert_push_event(view, "play-sound", %{name: "start"})
  end

  test "and a refusal plays nothing", %{conn: conn} do
    view = visitor(conn)

    view
    |> element("form[phx-submit=start]")
    |> render_submit(%{"name" => "", "race_id" => "0", "path" => "fighter"})

    refute_push_event(view, "play-sound", %{})
  end

  test "the header carries the toggle, which only its hook drives", %{conn: conn} do
    view = visitor(conn)

    assert has_element?(view, "#sound-toggle[phx-hook=SoundToggle]")
  end

  test "but the error page, with no LiveView to drive it, does not", %{conn: conn} do
    refute conn |> get("/no-such-road") |> html_response(404) =~ "sound-toggle"
  end
end
