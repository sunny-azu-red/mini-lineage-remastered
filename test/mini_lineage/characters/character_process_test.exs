defmodule MiniLineage.CharactersTest do
  @moduledoc """
  The state layer against the real database: a character outlives its process, concurrent actions
  cannot interleave, and each effect expires on its own timer rather than on the next read.
  """
  use MiniLineage.DataCase, async: false

  alias MiniLineage.Characters
  alias MiniLineage.Characters.{Record, Store, Sweeper}
  alias MiniLineage.Game.{Constants, Player}

  setup do
    id = Characters.new_id()
    on_exit(fn -> Characters.forget(id) end)

    {:ok, id: id}
  end

  defp start_character(id, race_id \\ 0) do
    Characters.mutate(id, fn player ->
      {player, _flash} = Player.initialize(player, Constants.race(race_id), "Hero")
      {%{player | current_screen: "home"}, :ok}
    end)
  end

  test "a character survives its process dying — today's characters live 24h", %{id: id} do
    start_character(id)
    hold(id)
    Characters.mutate(id, &{%{&1 | adena: 4242, experience: 900}, :ok})

    [{pid, _}] = Registry.lookup(MiniLineage.Characters.Registry, id)
    ref = Process.monitor(pid)
    GenServer.stop(pid, :normal)
    assert_receive {:DOWN, ^ref, :process, ^pid, _}, 1_000

    # Nothing is in memory now; this read must come off the database.
    reloaded = Characters.snapshot(id)

    assert reloaded.name == "Hero"
    assert reloaded.adena == 4242
    assert reloaded.experience == 900
    assert Enum.any?(reloaded.effects, &(&1.id == "newbie_blessing"))
    assert Enum.any?(reloaded.effects, &(&1.id == "resting"))
  end

  test "concurrent actions on one character cannot interleave into a lost update", %{id: id} do
    start_character(id)
    Characters.mutate(id, &{%{&1 | adena: 0}, :ok})

    # The reference needed a promise mutex for this; here it is the process itself.
    1..50
    |> Task.async_stream(fn _ -> Characters.mutate(id, &{%{&1 | adena: &1.adena + 1}, :ok}) end,
      max_concurrency: 25
    )
    |> Stream.run()

    assert Characters.snapshot(id).adena == 50
  end

  test "a change that changes nothing is not a change", %{id: id} do
    # Decided by comparing the struct rather than by the handler saying so, which is what makes a
    # read — a snapshot runs through the same path — cost nothing.
    start_character(id)
    Characters.mutate(id, &{%{&1 | adena: 4242}, :ok})

    written = Store.load(id)
    Characters.mutate(id, &{&1, :ok})

    assert Store.load(id) == written
  end

  test "an effect expires on its own timer, pushing the change without anyone reading", %{id: id} do
    start_character(id)
    hold(id)
    Characters.subscribe(id)

    deadline = System.system_time(:millisecond) + 60

    Characters.mutate(id, fn player ->
      effects =
        Enum.map(player.effects, fn e ->
          if e.id == "newbie_blessing", do: %{e | expires_at: deadline}, else: e
        end)

      {%{player | effects: effects}, :ok}
    end)

    # The mutation's own broadcast still carries the blessing...
    assert_receive {:character_updated, mutated}, 1_000
    assert Enum.any?(mutated.effects, &(&1.id == "newbie_blessing"))

    # ...and the timer's does not. Nothing read the character in between.
    assert_receive {:character_updated, expired}, 2_000
    refute Enum.any?(expired.effects, &(&1.id == "newbie_blessing"))
  end

  test "the regeneration tick heals a resting, wounded character", %{id: id} do
    start_character(id, 2)
    hold(id)
    Characters.mutate(id, &{%{&1 | health: 10}, :ok})

    [{pid, _}] = Registry.lookup(MiniLineage.Characters.Registry, id)
    send(pid, :tick)

    # Elf regen is 3.
    assert Characters.snapshot(id).health == 13
  end

  test "the tick does not heal a character standing in a combat zone", %{id: id} do
    start_character(id, 2)
    hold(id)
    Characters.mutate(id, &{%{&1 | health: 10, current_screen: "battle"}, :ok})

    [{pid, _}] = Registry.lookup(MiniLineage.Characters.Registry, id)
    send(pid, :tick)

    assert Characters.snapshot(id).health == 10
  end

  test "a character with no viewers stops on its own once the grace period elapses", %{id: id} do
    start_character(id)

    viewer = spawn(fn -> receive do: (:stop -> :ok) end)
    Characters.attach(id, viewer)

    [{pid, _}] = Registry.lookup(MiniLineage.Characters.Registry, id)
    ref = Process.monitor(pid)
    send(viewer, :stop)

    # State is already persisted, so stopping loses nothing.
    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 2_000
    assert Characters.snapshot(id).name == "Hero"
  end

  test "an unstarted character is never persisted, and never invents a health value", %{id: id} do
    # Elixir orders nil above every number, so the max-health clamp used to fire on nil health
    # and write a row for a visitor who had done nothing.
    assert Characters.snapshot(id) == %Player{}
    assert Characters.snapshot(id).health == nil
    assert MiniLineage.Characters.Store.load(id) == nil
  end

  test "the tick leaves a visitor who has no character alone", %{id: id} do
    # Reading the start page is what materializes the process. Its first tick used to raise on
    # `nil - nil` in the tick log, and the transient restart re-armed the timer to do it again.
    hold(id)
    assert Characters.snapshot(id) == %Player{}

    [{pid, _}] = Registry.lookup(MiniLineage.Characters.Registry, id)
    ref = Process.monitor(pid)
    send(pid, :tick)

    assert Characters.snapshot(id) == %Player{}
    refute_receive {:DOWN, ^ref, :process, ^pid, _}, 300
  end

  test "a process opened by a read alone stops itself, having never had a viewer", %{id: id} do
    # A dead render, a crawler or a health check reads and never connects. The stop timer used to
    # be armed only as a viewer left, so a process that never had one ticked forever.
    assert Characters.snapshot(id) == %Player{}

    [{pid, _}] = Registry.lookup(MiniLineage.Characters.Registry, id)
    ref = Process.monitor(pid)

    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 2_000
  end

  describe "the idle sweep" do
    test "leaves a character somebody is still playing", %{id: id} do
      start_character(id)
      # Counting rows rather than the sweep's return value: this database is shared with the
      # browser walkthrough, so a global count of zero is never a safe thing to assert.
      MiniLineage.Characters.Store.sweep_expired()

      assert Characters.snapshot(id).name == "Hero"
    end

    test "drops one nobody has touched for longer than the window", %{id: id} do
      start_character(id)
      Characters.forget_process(id)

      # Backdated past the window, as if the browser had been closed that long ago.
      stale = DateTime.add(DateTime.utc_now(), -(Store.ttl_hours() + 1) * 3600, :second)
      Repo.update_all(from(r in Record, where: r.id == ^id), set: [updated_at: stale])

      assert MiniLineage.Characters.Store.sweep_expired() >= 1
      assert Store.load(id) == nil
    end

    test "the scheduled sweeper does the same work, through its own process", %{id: id} do
      start_character(id)
      Characters.forget_process(id)

      stale = DateTime.add(DateTime.utc_now(), -(Store.ttl_hours() + 1) * 3600, :second)
      Repo.update_all(from(r in Record, where: r.id == ^id), set: [updated_at: stale])

      # Through the GenServer rather than Store directly: the hourly path has its own handler, and
      # nothing else exercises it.
      assert Sweeper.sweep_now() >= 1
      assert Store.load(id) == nil
    end

    test "the window slides: playing again resets the clock", %{id: id} do
      start_character(id)
      Characters.forget_process(id)

      stale = DateTime.add(DateTime.utc_now(), -(Store.ttl_hours() + 1) * 3600, :second)
      Repo.update_all(from(r in Record, where: r.id == ^id), set: [updated_at: stale])

      # Touching the character writes it again, which moves updated_at to now.
      Characters.mutate(id, &{%{&1 | adena: &1.adena + 1}, :ok})

      MiniLineage.Characters.Store.sweep_expired()
      assert Characters.snapshot(id).name == "Hero"
    end
  end
end
