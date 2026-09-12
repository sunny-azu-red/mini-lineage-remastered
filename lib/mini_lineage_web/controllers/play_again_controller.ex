defmodule MiniLineageWeb.PlayAgainController do
  @moduledoc """
  Starts a new run, which means a new identity.

  A LiveView cannot set a session cookie — it holds a WebSocket, not a response — so leaving a
  finished run behind has to pass through here. POST rather than GET on purpose: it archives the
  run, and a link a crawler or a prefetch could follow must never do that.

  The only controller in the app, so it imports what it needs rather than earning a `:controller`
  macro in `MiniLineageWeb` that nothing else would use.
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
