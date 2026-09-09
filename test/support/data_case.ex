defmodule MiniLineage.DataCase do
  @moduledoc """
  For tests that reach the database. Each runs inside the SQL sandbox, so whatever it writes is
  rolled back after it — but not concurrently: MyXQL is not Postgres, and `async: true` is unsafe.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias MiniLineage.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import MiniLineage.DataCase
    end
  end

  setup tags do
    MiniLineage.DataCase.setup_sandbox(tags)
    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(MiniLineage.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end

  @doc """
  Holds a character's process open for the rest of the test. With no viewer attached it stops
  itself once the idle grace elapses, which is deliberately short in this environment.
  """
  def hold(id) do
    viewer = spawn(fn -> receive do: (:stop -> :ok) end)
    MiniLineage.Characters.attach(id, viewer)
    on_exit(fn -> send(viewer, :stop) end)

    :ok
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
