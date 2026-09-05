defmodule MiniLineage.CharactersTest do
  @moduledoc """
  The state layer against the real database: a character outlives its process, concurrent actions
  cannot interleave, and each effect expires on its own timer rather than on the next read.
  """
  use MiniLineage.DataCase, async: false

  alias MiniLineage.Characters
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

  test "every persisted change bumps the revision, and a no-op change does not", %{id: id} do
    start_character(id)
    before = Characters.snapshot(id).revision

    Characters.mutate(id, &{%{&1 | adena: &1.adena + 1}, :ok})
    assert Characters.snapshot(id).revision == before + 1

    Characters.mutate(id, &{&1, :ok})
    assert Characters.snapshot(id).revision == before + 1
  end

  test "an effect expires on its own timer, pushing the change without anyone reading", %{id: id} do
    start_character(id)
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
    Characters.mutate(id, &{%{&1 | health: 10}, :ok})

    [{pid, _}] = Registry.lookup(MiniLineage.Characters.Registry, id)
    send(pid, :tick)

    # Elf regen is 3.
    assert Characters.snapshot(id).health == 13
  end

  test "the tick does not heal a character standing in a combat zone", %{id: id} do
    start_character(id, 2)
    Characters.mutate(id, &{%{&1 | health: 10, current_screen: "battle"}, :ok})

    [{pid, _}] = Registry.lookup(MiniLineage.Characters.Registry, id)
    send(pid, :tick)

    assert Characters.snapshot(id).health == 10
  end

  test "a character with no viewers stops on its own once the grace period elapses", %{id: id} do
    start_character(id)
    [{pid, _}] = Registry.lookup(MiniLineage.Characters.Registry, id)

    viewer = spawn(fn -> receive do: (:stop -> :ok) end)
    Characters.attach(id, viewer)

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

  test "the 24h sweep drops only characters nobody has touched", %{id: id} do
    start_character(id)
    assert MiniLineage.Characters.Store.sweep_expired() == 0
    assert Characters.snapshot(id).name == "Hero"
  end
end
