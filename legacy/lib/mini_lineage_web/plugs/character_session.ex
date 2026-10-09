defmodule MiniLineageWeb.Plugs.CharacterSession do
  @moduledoc """
  Puts an opaque session id in the signed session cookie. It identifies the BROWSER, not the
  character: the character's own id is public and appears in every board link, so the two are kept
  apart — otherwise a champion's link would be a working cookie for playing as them.
  """
  import Plug.Conn

  alias MiniLineage.Characters

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  # Put on every visit, not only the first: a cookie is re-issued only when the session is written,
  # and `max_age` would otherwise count from the first visit, however often the player came back.
  def call(conn, _opts),
    do:
      put_session(
        conn,
        :session_id,
        get_session(conn, :session_id) || Characters.new_session_id()
      )
end
