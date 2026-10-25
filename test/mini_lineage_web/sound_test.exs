defmodule MiniLineageWeb.SoundTest do
  @moduledoc """
  The new-game fanfare, pushed by the server when a character is made, and the toggle's own chime,
  which the browser plays without asking anybody. A new level's and a death's are the hunt's.
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

  test "a green alert chimes, and a blue one plays nothing", %{conn: conn} do
    session = Characters.new_session_id()
    on_exit(fn -> Characters.forget(session) end)
    conn = init_test_session(conn, %{"session_id" => session})
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> element("form[phx-submit=start]")
    |> render_submit(%{"name" => "Heard", "race_id" => "0", "path" => "fighter"})

    assert_push_event(view, "play-sound", %{name: "start"})

    for <<letter <- "adena">>, do: render_hook(view, "key", %{"key" => <<letter>>})
    assert has_element?(view, "#flash.alert-info")
    refute_push_event(view, "play-sound", %{})

    {:ok, view, _html} = live(conn, ~p"/talking-island-village/traders/weapon-trader")
    view |> form("#buy-form", %{"item" => "Bone Dagger"}) |> render_submit()
    assert has_element?(view, "#flash.alert-success")
    assert_push_event(view, "play-sound", %{name: "success"})
  end

  test "the header carries the toggle, which only its hook drives", %{conn: conn} do
    view = visitor(conn)

    assert has_element?(view, "#sound-toggle[phx-hook=SoundToggle]")
  end

  # `MiniLineageWeb.Kept`: served as the reader left it, so the hook never has to swap the face.
  test "the toggle is served muted for a reader who muted it, and sounding otherwise", %{
    conn: conn
  } do
    toggle = fn conn ->
      session = Characters.new_session_id()
      on_exit(fn -> Characters.forget(session) end)

      conn
      |> init_test_session(%{"session_id" => session})
      |> get(~p"/")
      |> html_response(200)
      |> LazyHTML.from_document()
      |> LazyHTML.query("#sound-toggle")
    end

    classes = fn toggle -> toggle |> LazyHTML.attribute("class") |> hd() |> String.split() end

    sounding = toggle.(conn)
    assert LazyHTML.text(sounding) == "🔊"
    assert classes.(sounding) == ~w(sound-toggle-btn)

    muted = conn |> put_req_cookie(MiniLineageWeb.Kept.cookie(), "sound%3Aeffects=0") |> toggle.()
    assert LazyHTML.text(muted) == "🔇"
    assert classes.(muted) == ~w(sound-toggle-btn silenced)
    assert LazyHTML.attribute(muted, "title") == ["Sound FX Muted (Click to Unmute)"]
    # The faces the hook flips between are the server's, so neither language holds a copy.
    assert LazyHTML.attribute(muted, "data-on") == ["🔊"]
    assert LazyHTML.attribute(muted, "data-on-label") == ["Sound FX Enabled (Click to Mute)"]
  end

  test "but the error page, with no LiveView to drive it, does not", %{conn: conn} do
    refute conn |> get("/no-such-road") |> html_response(404) =~ "sound-toggle"
  end
end
