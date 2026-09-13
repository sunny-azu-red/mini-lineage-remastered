defmodule MiniLineageWeb.PlayAgainController do
  @moduledoc """
  Starts a new run, which means a new identity. A LiveView holds a WebSocket, not a response, so
  it cannot set the cookie — hence a controller. POST, not GET: it retires the run, and a crawler
  or a prefetch must never be able to follow a link that does that.
  """
  use Phoenix.Controller, formats: []
  use MiniLineageWeb, :verified_routes

  import Plug.Conn

  alias MiniLineage.Characters

  def create(conn, _params) do
    if session = get_session(conn, :session_id), do: Characters.archive(session)

    conn
    # The old session id must not survive: it names a run that is now on the board, and the row it
    # named no longer answers to it.
    |> put_session(:session_id, Characters.new_session_id())
    |> redirect(to: ~p"/")
  end
end
