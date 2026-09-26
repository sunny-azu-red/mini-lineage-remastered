defmodule MiniLineageWeb.ErrorHTMLTest do
  @moduledoc "Errors Phoenix raises before a LiveView mounts, in the game's own shell."
  # NOT async: it flips :debug_build and :app_version, and deletes APP_VERSION, all global.
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

  # "500 Internal Server Error" on the page and the real fault only in a terminal is two places to
  # look for one thing. Phoenix hands the view what blew up, so the page says the whole of it.
  test "and when there is a fault to show, it is the whole of it" do
    html =
      render_to_string(MiniLineageWeb.ErrorHTML, "500", "html",
        kind: :error,
        reason: %UndefinedFunctionError{
          module: MiniLineage.CharacterLog,
          function: :nope,
          arity: 2
        },
        stack: [
          {MiniLineageWeb.GameLive, :page_chronicle, 3, [file: ~c"game_live.ex", line: 170]}
        ]
      )

    assert html =~ "UndefinedFunctionError"
    assert html =~ "page_chronicle/3"
    assert html =~ "game_live.ex:170"
  end

  # A trace for a mistyped URL would bury the ones that matter.
  test "but a road that leads nowhere is not a fault, and gets no trace" do
    html =
      render_to_string(MiniLineageWeb.ErrorHTML, "404", "html",
        kind: :error,
        reason: %{},
        stack: []
      )

    assert html =~ "That road leads nowhere"
    assert html =~ "404 Not Found"
    refute html =~ "stacktrace"
  end

  # The rule above the way back is what parts it from the page. Where a fault is shown there is a
  # block sitting there already doing that, and a second line under it reads as a stutter.
  test "and the way back is parted from whatever stands above it, once" do
    shown = render_to_string(MiniLineageWeb.ErrorHTML, "500", "html", [])

    assert shown =~ ~s(class="last")
    refute shown =~ ~s(class="last back")
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

    # Not even when Phoenix hands it a real one: what a release is allowed to say does not depend
    # on how much it happens to know.
    test "not even the fault it was handed" do
      html =
        render_to_string(MiniLineageWeb.ErrorHTML, "500", "html",
          kind: :error,
          reason: %UndefinedFunctionError{module: Secret, function: :key, arity: 0},
          stack: [{Secret, :key, 0, [file: ~c"secret.ex", line: 1]}]
        )

      refute html =~ "UndefinedFunctionError"
      refute html =~ "secret.ex"
      refute html =~ "code-block"
    end

    # With nothing above it, the way back needs the rule to part it from the message.
    test "and the way back draws its own line, there being nothing above it to do so" do
      assert render_to_string(MiniLineageWeb.ErrorHTML, "500", "html", []) =~
               ~s(class="last back")
    end

    test "and still none when nobody stamped a version" do
      # The image built without APP_VERSION cannot name its commit. That must cost it the footer
      # link and nothing else — tying the two is how a deployed release came to serve stack traces.
      System.delete_env("APP_VERSION")
      stamped = Application.get_env(:mini_lineage, :app_version)
      Application.delete_env(:mini_lineage, :app_version)
      on_exit(fn -> stamped && Application.put_env(:mini_lineage, :app_version, stamped) end)

      html = render_to_string(MiniLineageWeb.ErrorHTML, "500", "html", [])

      assert MiniLineage.Game.Version.current() == "🔥development"
      refute html =~ "code-block"
      refute html =~ "Internal Server Error"
    end
  end
end
