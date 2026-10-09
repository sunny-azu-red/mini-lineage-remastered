defmodule MiniLineageWeb.NightPageTest do
  @moduledoc """
  Nightfall changes nothing a character stores, so nothing is pushed for it: the page wakes itself
  at dusk and dawn and redraws what the hour changed. The clock is pinned in the test, which the
  page reads through `$callers`.
  """
  use MiniLineageWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias MiniLineage.Characters
  alias MiniLineage.Game.Clock

  defp dark_elf(conn) do
    session = Characters.new_session_id()
    on_exit(fn -> Characters.forget(session) end)
    {:ok, view, _html} = conn |> init_test_session(%{"session_id" => session}) |> live(~p"/")

    view
    |> element("form[phx-submit=start]")
    |> render_submit(%{"name" => "Nightwalker", "race_id" => "3", "path" => "fighter"})

    view
  end

  test "the header shows the night, and the Shadow Sense that answers it", %{conn: conn} do
    Clock.put_now(~U[2026-07-01 20:00:00Z])
    view = dark_elf(conn)

    assert has_element?(view, ~s(#effects [data-effect-id="night"]))
    assert has_element?(view, ~s(#effects [data-effect-id="shadow_sense"]))
    render_patch(view, ~p"/character")
    assert has_element?(view, ~s(#screen [data-key="char-accuracy"][data-value="36"]))
  end

  test "the night is a debuff and Shadow Sense a buff, each change in Accuracy's colour", %{
    conn: conn
  } do
    Clock.put_now(~U[2026-07-01 20:00:00Z])
    view = dark_elf(conn)

    assert has_element?(view, ~s(#effects .effect-debuff[data-effect-id="night"]))
    assert has_element?(view, ~s(#effects .effect-buff[data-effect-id="shadow_sense"]))
    render_patch(view, ~p"/character")
    assert has_element?(view, "#effect-night .debuff", "Night")
    assert has_element?(view, "#effect-night .accuracy", "-3 Accuracy")
    assert has_element?(view, "#effect-shadow_sense .buff", "Shadow Sense")
    assert has_element?(view, "#effect-shadow_sense .accuracy", "+3 Accuracy")
  end

  test "and dawn takes both away without anything being pushed", %{conn: conn} do
    Clock.put_now(~U[2026-07-01 20:00:00Z])
    view = dark_elf(conn)

    Clock.put_now(~U[2026-07-02 03:00:01Z])
    send(view.pid, :dusk_or_dawn)

    refute has_element?(view, ~s(#effects [data-effect-id="night"]))
    refute has_element?(view, ~s(#effects [data-effect-id="shadow_sense"]))
  end
end
