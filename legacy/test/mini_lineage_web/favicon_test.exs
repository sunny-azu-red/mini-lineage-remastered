defmodule MiniLineageWeb.FaviconTest do
  @moduledoc """
  A release links the icon by its digested name, `favicon-<hash>.ico`, and the static plug served
  only the exact names it was given, so every tab in production showed no icon at all.
  """
  use MiniLineageWeb.ConnCase, async: false

  test "is served by its digested name, as a release links it", %{conn: conn} do
    # What `phx.digest` writes, which a test build never runs. Ignored by git as every digest is.
    digested = Path.join(:code.priv_dir(:mini_lineage), "static/favicon-0000test.ico")
    File.cp!(Path.join(:code.priv_dir(:mini_lineage), "static/favicon.ico"), digested)
    on_exit(fn -> File.rm(digested) end)

    conn = get(conn, "/favicon-0000test.ico")

    assert conn.status == 200
    assert conn.resp_body == File.read!(digested)
  end

  test "and still by its own name", %{conn: conn} do
    assert get(conn, "/favicon.ico").status == 200
  end
end
