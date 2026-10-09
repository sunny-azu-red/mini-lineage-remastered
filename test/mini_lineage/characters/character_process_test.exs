defmodule MiniLineage.CharactersTest do
  @moduledoc """
  The state layer against the real database: a character outlives its process, concurrent actions
  cannot interleave, and the tick heals the wounded while nobody is reading.
  """
  use MiniLineage.DataCase, async: false

  alias MiniLineage.Characters
  alias MiniLineage.Characters.{Record, Store, Sweeper}
  alias MiniLineage.Game.{Constants, Player}

  setup do
    id = Characters.new_session_id()
    on_exit(fn -> Characters.forget(id) end)

    {:ok, id: id}
  end

  defp start_character(id, race_id \\ 0) do
    Characters.mutate(id, fn player ->
      {player, _flash} = Player.initialize(player, Constants.race(race_id), :fighter, "Hero")
      {player, :ok}
    end)
  end

  test "a character survives its process dying", %{id: id} do
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
  end

  test "concurrent actions on one character cannot interleave into a lost update", %{id: id} do
    start_character(id)
    Characters.mutate(id, &{%{&1 | adena: 0}, :ok})

    # No lock: the process itself serialises them.
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

    written = stored(id)
    Characters.mutate(id, &{&1, :ok})

    assert stored(id) == written
  end

  test "the regeneration tick heals a resting, wounded character", %{id: id} do
    start_character(id, 2)
    hold(id)
    Characters.mutate(id, &{%{&1 | health: 10}, :ok})

    [{pid, _}] = Registry.lookup(MiniLineage.Characters.Registry, id)
    send(pid, :tick)

    # An Elven Fighter rests 1.55 × 0.90 × 1.28 for CON 36 × 3 = 5.4 a tick (rules §11).
    assert Characters.snapshot(id).health == 15
  end

  test "a character with no viewers stops on its own once the grace period elapses", %{id: id} do
    start_character(id)

    {pid, ref} = leave(id)

    # State is already persisted, so stopping loses nothing.
    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 2_000
    assert Characters.snapshot(id).name == "Hero"
  end

  # Attach a viewer and let it go, which is what arms the stop.
  defp leave(id) do
    viewer = spawn(fn -> receive do: (:stop -> :ok) end)
    Characters.attach(id, viewer)

    [{pid, _}] = Registry.lookup(MiniLineage.Characters.Registry, id)
    ref = Process.monitor(pid)
    send(viewer, :stop)

    {pid, ref}
  end

  test "an unstarted character is never persisted, and never invents a health value", %{id: id} do
    # Elixir orders nil above every number, so a max-health clamp on nil health would write a row
    # for a visitor who had done nothing.
    assert Characters.snapshot(id) == %Player{}
    assert Characters.snapshot(id).health == nil
    assert stored(id) == nil
  end

  test "the tick leaves a visitor who has no character alone", %{id: id} do
    # Reading the start page materializes the process, and a tick on nil health must not raise:
    # the transient restart would re-arm the timer to do it again.
    hold(id)
    assert Characters.snapshot(id) == %Player{}

    [{pid, _}] = Registry.lookup(MiniLineage.Characters.Registry, id)
    ref = Process.monitor(pid)
    send(pid, :tick)

    assert Characters.snapshot(id) == %Player{}
    refute_receive {:DOWN, ^ref, :process, ^pid, _}, 300
  end

  test "a process opened by a read alone stops itself, having never had a viewer", %{id: id} do
    # A dead render, a crawler or a health check reads and never connects, so no viewer ever
    # leaves to arm the stop.
    assert Characters.snapshot(id) == %Player{}

    [{pid, _}] = Registry.lookup(MiniLineage.Characters.Registry, id)
    ref = Process.monitor(pid)

    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 2_000
  end

  describe "the idle retirement" do
    # A run nobody has come back to gives up only the session that tied it to a browser.
    defp backdate(session) do
      stale = DateTime.add(DateTime.utc_now(), -(Store.ttl_hours() + 1) * 3600, :second)

      Repo.update_all(from(r in Record, where: r.session_id == ^session),
        set: [updated_at: stale]
      )
    end

    test "leaves a character somebody is still playing", %{id: id} do
      start_character(id)
      Store.retire_idle()

      assert Characters.snapshot(id).name == "Hero"
      assert stored(id), "a character in play lost its session"
    end

    test "takes the session off one nobody has touched, and keeps the character", %{id: id} do
      start_character(id)
      character_id = stored_id(id)
      Characters.forget_process(id)
      backdate(id)

      assert Store.retire_idle() >= 1

      # The session is gone, so nothing can pick this run up again...
      assert stored(id) == nil
      # ...but the run itself is still here.
      assert Repo.get(Record, character_id).state["name"] == "Hero"
    end

    test "the scheduled sweeper does the same work, through its own process", %{id: id} do
      start_character(id)
      character_id = stored_id(id)
      Characters.forget_process(id)
      backdate(id)

      # Through the GenServer rather than Store directly: the hourly path has its own handler, and
      # nothing else exercises it.
      assert Sweeper.sweep_now() >= 1
      assert stored(id) == nil
      assert Repo.get(Record, character_id)
    end

    test "the window slides: playing again resets the clock", %{id: id} do
      start_character(id)
      Characters.forget_process(id)
      backdate(id)

      # Touching the character writes it again, which moves updated_at to now.
      Characters.mutate(id, &{%{&1 | adena: &1.adena + 1}, :ok})

      Store.retire_idle()

      assert Characters.snapshot(id).name == "Hero"
      assert stored(id), "a character played a moment ago was retired"
    end
  end
end
