defmodule MiniLineageWeb.ConnCase do
  @moduledoc """
  For tests that need a connection. Each runs inside the SQL sandbox, so whatever it writes is
  rolled back after it.

  A test MAY be async when it touches nothing but the repo. Most here cannot: a character lives in
  a GenServer started by a DynamicSupervisor, so the sandbox cannot trace ownership from the test
  process to it and every query from the character raises. Shared mode is what bridges that, and
  shared mode means `async: false`.
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
