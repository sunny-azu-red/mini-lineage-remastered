defmodule MiniLineage.Characters.NonMutatingReadsTest do
  @moduledoc """
  Reading a character never plays it. Connecting, reconnecting and refreshing go through the same
  `run/3` as an action, so only the fact that no read asks it to stops a read from fighting.
  """
  use MiniLineage.DataCase, async: false

  alias MiniLineage.Characters
  alias MiniLineage.Game.{Actions, Constants, Player}

  setup do
    id = Characters.new_session_id()
    on_exit(fn -> Characters.forget(id) end)

    Characters.mutate(id, fn player ->
      {player, _} = Player.initialize(player, Constants.race(1), :fighter, "Hero")
      {%{player | current_screen: "battle"}, :ok}
    end)

    # A fatal fight counts no battle, and these compare counters across a read.
    pin_dice(id)

    {:ok, id: id}
  end

  defp counters(id) do
    p = Characters.snapshot(id)
    {p.total_battles, p.experience, p.adena, p.health}
  end

  test "reading it a hundred times fights no battles", %{id: id} do
    before = counters(id)

    for _ <- 1..100, do: Characters.snapshot(id)

    assert counters(id) == before
  end

  test "attaching a viewer does not either, which is what a page load does", %{id: id} do
    before = counters(id)

    for _ <- 1..10 do
      Characters.attach(id, self())
      Characters.snapshot(id)
    end

    assert counters(id) == before
  end

  test "and the process restarting mid-run resumes rather than replays", %{id: id} do
    Characters.mutate(id, &Actions.fight/1)
    before = counters(id)

    [{pid, _}] = Registry.lookup(MiniLineage.Characters.Registry, id)
    ref = Process.monitor(pid)
    GenServer.stop(pid, :normal)
    assert_receive {:DOWN, ^ref, :process, ^pid, _}, 1_000

    # Comes back off the database, and coming back is a read.
    assert counters(id) == before
  end
end
