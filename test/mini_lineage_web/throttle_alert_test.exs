defmodule MiniLineageWeb.ThrottleAlertTest do
  @moduledoc """
  A throttle warning is the flash of the action it refused, so it stays on the screen it was raised
  on and is dropped on arrival anywhere else, or once the window reopens.
  """
  # Flips the rate limit on in Application env, which another async module would read mid-flip.
  use MiniLineageWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias MiniLineage.{Characters, Repo}
  alias MiniLineage.Characters.Store
  alias MiniLineage.Game.{Constants, Format, Player, RateLimit}

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

  @warning "#flash [data-remaining-ms]"

  defp flood(session, limiter, times),
    do: for(_ <- 1..times, do: RateLimit.check(session, limiter))

  defp warning(view), do: view |> render() |> LazyHTML.from_fragment() |> LazyHTML.query("#flash")

  test "a fight's warning stays at the Battleground", %{conn: conn, session: session} do
    {:ok, view, _} = live(conn, ~p"/")

    flood(session, :battle, 60)
    render_click(view, "navigate", %{"to" => "battle"})
    assert has_element?(view, @warning)

    # A link, where the shop leaves by an event: the two drop a flash in different places.
    render_patch(view, ~p"/highscores")
    refute has_element?(view, "#flash")
  end

  test "a shop's warning stays in the shop", %{conn: conn, session: session} do
    {:ok, view, _} = live(conn, ~p"/shop/weapons")

    flood(session, :shop, 30)
    render_submit(view, "purchase", %{"item_id" => "1", "type" => "weapon"})
    assert has_element?(view, @warning)

    render_click(view, "navigate", %{"to" => "home"})
    assert_patch(view, ~p"/")
    refute has_element?(view, "#flash")
  end

  test "the wait is drawn for the hook to count down", %{conn: conn, session: session} do
    {:ok, view, _} = live(conn, ~p"/battle")

    flood(session, :battle, 60)
    render_click(view, "fight")

    [ms] =
      view
      |> warning()
      |> LazyHTML.query("[data-remaining-ms]")
      |> LazyHTML.attribute("data-remaining-ms")

    ms = String.to_integer(ms)
    label = view |> warning() |> LazyHTML.query("[data-timer=long]") |> LazyHTML.text()

    assert ms in 1..60_000
    assert label == Format.remaining(ms)
    assert has_element?(view, "#flash[phx-hook=EffectTimers]")
  end

  test "the warning goes when the window reopens, and not for an older one's timer",
       %{conn: conn, session: session} do
    {:ok, view, _} = live(conn, ~p"/battle")

    flood(session, :battle, 60)
    render_click(view, "fight")
    %{game_flash: %{expires: ref}} = :sys.get_state(view.pid).socket.assigns

    send(view.pid, {:flash_expired, make_ref()})
    assert has_element?(view, @warning)

    send(view.pid, {:flash_expired, ref})
    refute has_element?(view, "#flash")
  end

  test "an ambush, the road and the shop each say it their own way",
       %{conn: conn, session: session} do
    flood(session, :battle, 60)
    flood(session, :shop, 30)

    # The shop first: an ambushed run is pinned to the Battleground.
    {:ok, shop, _} = live(conn, ~p"/shop/weapons")
    render_submit(shop, "purchase", %{"item_id" => "1", "type" => "weapon"})
    store = shop |> warning() |> LazyHTML.text()

    {:ok, view, _} = live(conn, ~p"/battle")
    render_click(view, "fight")
    road = view |> warning() |> LazyHTML.text()

    Characters.mutate(session, &{%{&1 | ambushed: true}, {:ok, nil}})
    render_click(view, "fight")
    ambush = view |> warning() |> LazyHTML.text()

    assert road =~ "seek another fight"
    assert ambush =~ "The ambush waits"
    assert store =~ "shopkeeper"
  end
end
