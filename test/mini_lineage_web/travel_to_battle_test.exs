defmodule MiniLineageWeb.TravelToBattleTest do
  @moduledoc """
  Travelling to the Battleground fights on arrival, so one click both moves the player and can
  kill them. A socket holds a single patch, and this is where it once asked for two.
  """
  use MiniLineageWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias MiniLineage.{Characters, Repo}
  alias MiniLineage.Characters.Store
  alias MiniLineage.Game.{Constants, Player}

  setup %{conn: conn} do
    Repo.query!("DELETE FROM character_log")
    Repo.query!("DELETE FROM characters")

    # A fight costs at least ten before armour and an Orc has no regeneration, so 1 HP is fatal
    # whatever the dice say.
    session = Characters.new_session_id()
    {player, _} = Player.initialize(%Player{}, Constants.race(1), "Doomed")
    :ok = Store.save(Store.new_id(), session, %{player | health: 1})

    %{conn: init_test_session(conn, %{"session_id" => session}), session: session}
  end

  test "a fatal first fight lands on the death screen", %{conn: conn} do
    {:ok, view, _} = live(conn, ~p"/")

    render_click(view, "navigate", %{"to" => "battle"})

    assert_patch(view, ~p"/")
    assert render(view) =~ "Game Over"
  end

  test "a fight survived lands on the Battleground", %{conn: conn, session: session} do
    {:ok, view, _} = live(conn, ~p"/")
    Characters.mutate(session, &{%{&1 | health: 5_000}, {:ok, nil}})

    render_click(view, "navigate", %{"to" => "battle"})

    assert_patch(view, ~p"/battle")
  end
end
