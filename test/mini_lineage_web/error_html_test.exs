defmodule MiniLineageWeb.ErrorHTMLTest do
  @moduledoc "Errors Phoenix raises before a LiveView mounts, in the game's own shell."
  use MiniLineageWeb.ConnCase, async: false

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

  describe "a production build" do
    setup do
      Application.put_env(:mini_lineage, :debug_build, false)
      on_exit(fn -> Application.put_env(:mini_lineage, :debug_build, true) end)
    end

    test "hands out no internals" do
      html = render_to_string(MiniLineageWeb.ErrorHTML, "500", "html", [])

      refute html =~ "code-block"
      refute html =~ "Internal Server Error"
      assert html =~ "An unexpected error occurred on the server"
    end

    test "and still none when nobody stamped a version" do
      # The image built without APP_VERSION cannot name its commit. That must cost it the footer
      # link and nothing else — tying the two is how a deployed release came to serve stack traces.
      System.delete_env("APP_VERSION")
      stamped = Application.get_env(:mini_lineage, :app_version)
      Application.delete_env(:mini_lineage, :app_version)
      on_exit(fn -> stamped && Application.put_env(:mini_lineage, :app_version, stamped) end)

      html = render_to_string(MiniLineageWeb.ErrorHTML, "500", "html", [])

      assert MiniLineage.Game.Version.current() == "production"
      refute html =~ "code-block"
      refute html =~ "Internal Server Error"
    end
  end
end
