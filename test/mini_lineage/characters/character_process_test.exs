defmodule MiniLineage.CharactersTest do
  @moduledoc """
  The state layer against the real database: a character outlives its process, concurrent actions
  cannot interleave, and each effect expires on its own timer rather than on the next read.
  """
  use MiniLineage.DataCase, async: false

  alias MiniLineage.{Board, CharacterLog, Characters}
  alias MiniLineage.Characters.{Record, Store, Sweeper}
  alias MiniLineage.Game.{Constants, Player}

  setup do
    id = Characters.new_session_id()
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

    written = stored(id)
    Characters.mutate(id, &{&1, :ok})

    assert stored(id) == written
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
    assert_receive {:character_updated, mutated, _id}, 1_000
    assert Enum.any?(mutated.effects, &(&1.id == "newbie_blessing"))

    # ...and the timer's does not. Nothing read the character in between.
    assert_receive {:character_updated, expired, _id}, 2_000
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
    Characters.mutate(id, &{%{&1 | effects: []}, :ok})

    {pid, ref} = leave(id)

    # State is already persisted, so stopping loses nothing.
    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 2_000
    assert Characters.snapshot(id).name == "Hero"
  end

  # Otherwise a buff lapsing after the tab closed would be logged whenever the player came back,
  # or never, while a stranger's page had already stopped showing it.
  test "but one with a buff still to lapse stays up to write it, and then stops", %{id: id} do
    start_character(id)
    lapses_at = System.system_time(:millisecond) + 400

    Characters.mutate(
      id,
      &{%{&1 | effects: Enum.map(&1.effects, fn e -> lapsing(e, lapses_at) end)}, :ok}
    )

    {pid, ref} = leave(id)

    refute_receive {:DOWN, ^ref, :process, ^pid, _}, 250
    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 2_000

    character = Characters.character_id(id)

    assert Enum.any?(
             CharacterLog.recent(character),
             &(&1.kind == "buff" and &1.line =~ "leaves")
           )
  end

  # Kept up for a lapse, it is still a player who has gone: nobody heals while they are away.
  test "and does not heal the player while it waits", %{id: id} do
    start_character(id)
    Characters.mutate(id, &{%{&1 | health: 10}, :ok})

    {pid, ref} = leave(id)
    refute_receive {:DOWN, ^ref, :process, ^pid, _}, 250

    send(pid, :tick)
    assert :sys.get_state(pid).player.health == 10
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

  defp lapsing(%{id: "newbie_blessing"} = effect, at), do: %{effect | expires_at: at}
  defp lapsing(effect, _at), do: effect

  test "an unstarted character is never persisted, and never invents a health value", %{id: id} do
    # Elixir orders nil above every number, so the max-health clamp used to fire on nil health
    # and write a row for a visitor who had done nothing.
    assert Characters.snapshot(id) == %Player{}
    assert Characters.snapshot(id).health == nil
    assert stored(id) == nil
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

  describe "the idle retirement" do
    # Nothing ages out of the table any more. A run nobody has come back to has still been played,
    # so it keeps its place in the Halls and gives up only the session that tied it to a browser.
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
      # ...but the run itself is still here, and still in the Halls.
      assert Repo.get(Record, character_id)
      assert Board.entry(character_id).name == "Hero"
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
