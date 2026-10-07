defmodule MiniLineageWeb.ConnCase do
  @moduledoc """
  For tests that need a connection. Each runs inside the SQL sandbox and is rolled back. Only
  a test touching nothing but the repo may be async: a character's GenServer is started by a
  DynamicSupervisor, so the sandbox needs shared mode to reach it, and shared mode is serial.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint MiniLineageWeb.Endpoint

      use MiniLineageWeb, :verified_routes

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
