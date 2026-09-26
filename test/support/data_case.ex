defmodule MiniLineage.DataCase do
  @moduledoc """
  For tests that reach the database. Each runs inside the SQL sandbox, so whatever it writes is
  rolled back after it.

  A test MAY be async when it touches nothing but the repo. Most here cannot: a character lives in
  a GenServer started by a DynamicSupervisor, so the sandbox cannot trace ownership from the test
  process to it. Shared mode bridges that, and shared mode means `async: false`.
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
  The player as the database has it, found the way the game finds it — by the session, not by the
  character's public id, which a test holding a cookie would not know.
  """
  def stored(session) do
    case MiniLineage.Characters.Store.load_by_session(session) do
      {_id, player} -> player
      nil -> nil
    end
  end

  @doc "The public id of the character this session is playing, or nil before it has saved."
  def stored_id(session) do
    case MiniLineage.Characters.Store.load_by_session(session) do
      {id, _player} -> id
      nil -> nil
    end
  end

  @doc """
  What `fun` logs at :debug. The suite runs at :warning, so the level is raised for this call alone:
  raised for a whole test, everything around the capture prints, a viewer attaching or leaving.
  """
  def capture_debug(fun) do
    previous = Logger.level()
    Logger.configure(level: :debug)

    try do
      ExUnit.CaptureLog.capture_log([level: :debug], fun)
    after
      Logger.configure(level: previous)
    end
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
