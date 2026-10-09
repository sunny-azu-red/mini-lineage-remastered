defmodule MiniLineageWeb.DevTimeTest do
  @moduledoc """
  Typing `night` or `day` in a debug build holds the whole world at that hour, whatever the clock
  says, until the other word or a restart. Not async: the hour is the node's, and a release is a
  flip of the debug build. A pinned time still beats it, which is what keeps the async suites safe.
  """
  use MiniLineageWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias MiniLineage.Characters
  alias MiniLineage.Game.Clock

  setup do
    on_exit(fn -> Clock.force(nil) end)
  end

  defp started(conn, race_id) do
    session = Characters.new_session_id()
    on_exit(fn -> Characters.forget(session) end)
    {:ok, view, _html} = conn |> init_test_session(%{"session_id" => session}) |> live(~p"/")

    view
    |> element("form[phx-submit=start]")
    |> render_submit(%{"name" => "Timekeeper", "race_id" => race_id, "path" => "fighter"})

    view
  end

  defp type(view, letters),
    do: for(<<l <- letters>>, do: render_hook(view, "key", %{"key" => <<l>>}))

  defp night?(view), do: has_element?(view, ~s(#effects [data-effect-id="night"]))

  test "night falls on every page at once, and day lifts it, whatever the hour" do
    typist = started(build_conn(), "0")
    elsewhere = started(build_conn(), "3")

    type(typist, "night")
    assert night?(typist)
    assert night?(elsewhere)
    assert has_element?(elsewhere, ~s(#effects [data-effect-id="shadow_sense"]))

    type(typist, "day")
    refute night?(typist)
    refute night?(elsewhere)
  end

  test "a pinned time beats it, so a test that pins is never moved by one that forces" do
    :ok = Clock.force(:night)
    Clock.put_now(~U[2026-07-01 09:00:00Z])
    refute Clock.night?()

    :ok = Clock.force(:day)
    Clock.put_now(~U[2026-07-01 20:00:00Z])
    assert Clock.night?()
  end

  test "a release refuses, whoever asks" do
    previous = Application.fetch_env!(:mini_lineage, :debug_build)
    Application.put_env(:mini_lineage, :debug_build, false)
    on_exit(fn -> Application.put_env(:mini_lineage, :debug_build, previous) end)

    assert Clock.force(:night) == :error
    assert Clock.forced() == nil

    view = started(build_conn(), "0")
    type(view, "night")
    assert Clock.forced() == nil
  end
end
