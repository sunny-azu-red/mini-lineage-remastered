defmodule MiniLineage.Characters.NonMutatingReadsTest do
  @moduledoc """
  Reading a character never plays it.

  Connecting, reconnecting and refreshing all go through the same `run/3` as an action, so nothing
  structural stops a read from fighting — only the fact that no read asks it to. That is what makes
  navigating away mid-ambush pointless rather than merely punished: the ambush is still there when
  you come back, and coming back did not resolve it.
  """
  use MiniLineage.DataCase, async: false

  alias MiniLineage.Characters
  alias MiniLineage.Characters.Store
  alias MiniLineage.Game.{Actions, Constants, Player}

  setup do
    id = Characters.new_id()
    on_exit(fn -> Characters.forget(id) end)

    Characters.mutate(id, fn player ->
      {player, _} = Player.initialize(player, Constants.race(1), "Hero")
      # Tanky enough that no roll below is fatal: a fatal fight counts no battle, and these
      # compare counters across a read.
      {%{player | current_screen: "battle", health: 5_000}, :ok}
    end)

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

  describe "an ambush" do
    test "survives walking away and reading the character back", %{id: id} do
      # Forced rather than rolled: the point is what a read does to it, not how it arrived.
      Characters.mutate(id, &{%{&1 | ambushed: true}, :ok})

      for _ <- 1..20, do: Characters.snapshot(id)

      assert Characters.snapshot(id).ambushed, "a read resolved the ambush"
      assert Store.load(id).ambushed, "the ambush was not there on reload"
    end

    test "and is only ever answered by fighting", %{id: id} do
      Characters.mutate(id, &{%{&1 | ambushed: true}, :ok})
      before = Characters.snapshot(id).total_battles

      Characters.mutate(id, &Actions.fight/1)

      # Answering it costs a fight, which is the whole point — the roll may hand out another
      # ambush, so what is asserted is that one was fought, not that none remains.
      assert Characters.snapshot(id).total_battles == before + 1
    end
  end
end
