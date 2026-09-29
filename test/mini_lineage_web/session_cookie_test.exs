defmodule MiniLineageWeb.SessionCookieTest do
  @moduledoc """
  The session cookie is re-issued on every visit, so its 30 days run from the last one. Issued only
  once, a player who came back every day lost their character on the thirtieth.
  """
  use MiniLineageWeb.ConnCase, async: false

  alias MiniLineage.Characters

  test "a returning browser has its session re-issued", %{conn: conn} do
    first = get(conn, ~p"/highscores")
    session = get_session(first, :session_id)
    on_exit(fn -> Characters.forget(session) end)

    # `recycle/1` carries the cookie over, as a browser coming back would.
    again = first |> recycle() |> get(~p"/highscores")

    assert get_session(again, :session_id) == session

    assert Enum.any?(
             get_resp_header(again, "set-cookie"),
             &String.starts_with?(&1, "_mini_lineage_key=")
           )
  end
end
