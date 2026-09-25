defmodule MiniLineageWeb.HealthTest do
  @moduledoc """
  The container's healthcheck sends no cookie. Pointed at a page, every probe minted a visitor and
  started a character process for it, twice a minute, for as long as the container ran.
  """
  use MiniLineageWeb.ConnCase, async: false

  test "answers without a session or a character", %{conn: conn} do
    before = Registry.count(MiniLineage.Characters.Registry)

    conn = get(conn, "/health")

    assert conn.status == 200
    assert get_resp_header(conn, "set-cookie") == []
    assert Registry.count(MiniLineage.Characters.Registry) == before
  end
end
