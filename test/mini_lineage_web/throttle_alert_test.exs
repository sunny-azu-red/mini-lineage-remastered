defmodule MiniLineageWeb.ThrottleAlertTest do
  @moduledoc """
  A throttle warning is the flash of the action it refused, so it stays on the screen it was raised
  on and is dropped on arrival anywhere else.
  """
  # Flips the rate limit on in Application env, which another async module would read mid-flip.
  use MiniLineageWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias MiniLineage.{Characters, Repo}
  alias MiniLineage.Characters.Store
  alias MiniLineage.Game.{Constants, Player, RateLimit}

  setup %{conn: conn} do
    Repo.query!("DELETE FROM character_log")
    Repo.query!("DELETE FROM characters")
    Application.put_env(:mini_lineage, :rate_limit, true)
    on_exit(fn -> Application.put_env(:mini_lineage, :rate_limit, false) end)

    session = Characters.new_session_id()
    {player, _} = Player.initialize(%Player{}, Constants.race(1), "Hasty")
    :ok = Store.save(Store.new_id(), session, %{player | health: 5_000})
    on_exit(fn -> Characters.forget(session) end)

    %{conn: init_test_session(conn, %{"session_id" => session}), session: session}
  end

  test "a fight's warning stays at the Battleground", %{conn: conn, session: session} do
    {:ok, view, _} = live(conn, ~p"/")

    for _ <- 1..60, do: RateLimit.check(session, :battle)
    render_click(view, "navigate", %{"to" => "battle"})
    assert render(view) =~ "moving too fast"

    # A link, where the shop leaves by an event: the two drop a flash in different places.
    render_patch(view, ~p"/highscores")
    refute render(view) =~ "moving too fast"
  end

  test "a shop's warning stays in the shop", %{conn: conn, session: session} do
    {:ok, view, _} = live(conn, ~p"/shop/weapons")

    for _ <- 1..30, do: RateLimit.check(session, :shop)
    render_submit(view, "purchase", %{"item_id" => "1", "type" => "weapon"})
    assert render(view) =~ "moving too fast"

    render_click(view, "navigate", %{"to" => "home"})
    assert_patch(view, ~p"/")
    refute render(view) =~ "moving too fast"
  end
end
