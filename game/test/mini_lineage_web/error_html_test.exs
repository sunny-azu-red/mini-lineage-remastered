defmodule MiniLineageWeb.ErrorHTMLTest do
  @moduledoc "Errors Phoenix raises before a LiveView mounts, in the game's own shell."
  use MiniLineageWeb.ConnCase, async: true

  import Phoenix.Template, only: [render_to_string: 4]

  test "a 404 wears the game's shell rather than bare text" do
    html = render_to_string(MiniLineageWeb.ErrorHTML, "404", "html", [])

    assert html =~ "That road leads nowhere"
    assert html =~ ~s(id="app")
    assert html =~ "/assets/css/app.css"
    assert html =~ "Return to safer lands"
  end

  test "a 500 does not blame the player for it" do
    html = render_to_string(MiniLineageWeb.ErrorHTML, "500", "html", [])

    assert html =~ "An unexpected error occurred on the server"
  end

  test "the reason is shown in a development build" do
    html = render_to_string(MiniLineageWeb.ErrorHTML, "500", "html", [])

    assert html =~ "code-block"
    assert html =~ "Internal Server Error"
  end

  test "and withheld from a release build, which must never hand out internals" do
    System.put_env("APP_VERSION", "a1b2c3d")
    on_exit(fn -> System.delete_env("APP_VERSION") end)

    html = render_to_string(MiniLineageWeb.ErrorHTML, "500", "html", [])

    refute html =~ "code-block"
    refute html =~ "Internal Server Error"
    assert html =~ "An unexpected error occurred on the server"
  end
end
