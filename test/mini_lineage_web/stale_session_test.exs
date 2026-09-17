defmodule MiniLineageWeb.StaleSessionTest do
  @moduledoc """
  A socket carrying a session the plug has never touched.

  The plug cannot reach a WebSocket, so a tab left open across a deploy — or anything reconnecting
  with a cookie this build did not issue — mounts without a session id. The mount has to survive
  that rather than taking the LiveView down with a query built from nil.
  """
  use MiniLineageWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias MiniLineage.Characters.Store

  describe "a cookie the plug never issued" do
    test "does not take the LiveView down", %{conn: conn} do
      # `live/2` will not reproduce this: it renders over HTTP first, so the plug heals the cookie
      # before the socket ever mounts. The failure needs a mount that the pipeline never touched,
      # which is exactly what a reconnecting socket is — and what `live_isolated/3` gives.
      assert {:error, {:redirect, %{to: "/"}}} =
               live_isolated(conn, MiniLineageWeb.GameLive, session: %{"unknown" => "key"})
    end

    test "and neither does a socket carrying no session at all", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} =
               live_isolated(conn, MiniLineageWeb.GameLive, session: %{})
    end

    test "though an ordinary page load heals it before the socket ever mounts", %{conn: conn} do
      # The reason this only ever bites a tab left open: any real navigation runs the plug.
      conn = init_test_session(conn, %{"unknown" => "key"})

      assert {:ok, _live, html} = live(conn, ~p"/")
      assert html =~ "Game Start"
    end

    test "and the request it is bounced to issues a real one", %{conn: conn} do
      conn = conn |> init_test_session(%{"unknown" => "key"}) |> get(~p"/")

      assert is_binary(get_session(conn, :session_id))
    end

    test "so the bounce cannot come back round a second time", %{conn: conn} do
      conn = conn |> init_test_session(%{"unknown" => "key"}) |> get(~p"/")

      # Same connection, now carrying what the plug issued: the LiveView mounts for real.
      {:ok, _live, html} = live(conn, ~p"/")

      assert html =~ "Game Start"
    end
  end

  describe "the store" do
    test "never builds a query from a session id that is not there" do
      # `where: r.session_id == ^nil` is not a query Ecto will build, and the ArgumentError it
      # raises instead came back as a CaseClauseError three frames away from the cause.
      assert Store.load_by_session(nil) == nil
    end
  end
end
