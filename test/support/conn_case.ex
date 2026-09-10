defmodule MiniLineageWeb.ConnCase do
  @moduledoc """
  For tests that need a connection. Each runs inside the SQL sandbox, so whatever it writes is rolled
  back after it — but not concurrently: MyXQL is not Postgres, and `async: true` is unsafe here.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint MiniLineageWeb.Endpoint

      use MiniLineageWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import MiniLineageWeb.ConnCase
    end
  end

  setup tags do
    MiniLineage.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
