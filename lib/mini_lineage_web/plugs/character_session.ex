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
  def call(conn, _opts) do
    case get_session(conn, :session_id) do
      nil -> conn |> put_session(:session_id, Characters.new_session_id()) |> drop_stale()
      _id -> conn
    end
  end

  # `character_id` was this key's name while the cookie also named the character. It is a session
  # id's worth of dead weight in every returning player's cookie, and deleting it is how the last
  # of them goes away.
  defp drop_stale(conn), do: delete_session(conn, :character_id)
end
