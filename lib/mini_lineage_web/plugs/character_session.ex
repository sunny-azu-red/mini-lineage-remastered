defmodule MiniLineageWeb.Plugs.CharacterSession do
  @moduledoc """
  Puts an opaque character id in the signed session cookie. The cookie carries identity only —
  the character itself lives in its own process, backed by the `characters` table.
  """
  import Plug.Conn

  alias MiniLineage.Characters

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    case get_session(conn, :character_id) do
      nil -> put_session(conn, :character_id, Characters.new_id())
      _id -> conn
    end
  end
end
