defmodule MiniLineage.Characters.BufferingTest do
  @moduledoc """
  What reaches the database, and when.

  A character is held in its process, so the database is durability rather than storage. Writing on
  every change cost roughly twenty writes per fight — almost all of them passive regeneration — so
  what the player did is written before they are told it worked, and the passage of time rides
  along with it. These tests pin both halves of that: that an action is durable immediately, and
  that a tick is not, because a bug in either direction is invisible from the game.
  """
  use MiniLineage.DataCase, async: false

  alias MiniLineage.Characters
  alias MiniLineage.Characters.Store
  alias MiniLineage.Game.{Constants, Player}

  setup do
    id = Characters.new_id()
    on_exit(fn -> Characters.forget(id) end)

    {:ok, id: id}
  end

  defp start_character(id) do
    Characters.mutate(id, fn player ->
      {player, _flash} = Player.initialize(player, Constants.race(0), "Hero")
      {%{player | current_screen: "home"}, :ok}
    end)
  end

  defp pid_for(id) do
    [{pid, _}] = Registry.lookup(MiniLineage.Characters.Registry, id)
    pid
  end

  # A tick, delivered directly rather than waited for: the cadence is five seconds and this suite
  # is not testing the timer.
  defp tick(id), do: send(pid_for(id), :tick)

  # The buffer lives in the process, so a call after the tick is what proves it was handled.
  defp settle(id), do: Characters.snapshot(id)

  describe "what is written immediately" do
    test "creating a character, because the session cookie points at a row that must exist", %{
      id: id
    } do
      start_character(id)

      assert Store.load(id).name == "Hero"
    end

    test "an action, before the player is told it worked", %{id: id} do
      start_character(id)
      Characters.mutate(id, &{%{&1 | adena: 4242}, :ok})

      assert Store.load(id).adena == 4242
    end

    test "and it carries the buffered time along with it", %{id: id} do
      start_character(id)
      Characters.mutate(id, &{%{&1 | health: 10}, :ok})

      tick(id)
      settle(id)
      regenerated = Characters.snapshot(id).health
      assert regenerated > 10, "the tick did not regenerate, so this test proves nothing"

      # Buffered until something the player did writes it.
      Characters.mutate(id, &{%{&1 | adena: 99}, :ok})

      assert Store.load(id).health == regenerated
    end
  end

  describe "what is buffered" do
    test "passive regeneration, which is the write this exists to remove", %{id: id} do
      start_character(id)
      Characters.mutate(id, &{%{&1 | health: 10}, :ok})
      persisted = Store.load(id).health
      wounded = Characters.snapshot(id).health

      tick(id)
      settle(id)

      assert Characters.snapshot(id).health > wounded, "the tick did not regenerate"
      assert Store.load(id).health == persisted, "a regen tick reached the database"
    end

    test "moving between screens, which cannot release an ambush pin", %{id: id} do
      start_character(id)
      # `pin_screen/2` reads `dead` and `ambushed`, never `current_screen`, so a stale screen on
      # disk cannot let a pinned player walk away from the battleground.
      Characters.mutate(id, &{%{&1 | current_screen: "inn"}, :ok})

      assert Characters.snapshot(id).current_screen == "inn"
      assert Store.load(id).current_screen == "home"
    end
  end

  describe "what survives losing the process" do
    test "a clean stop flushes, so the idle sweep and a deploy lose nothing", %{id: id} do
      start_character(id)
      Characters.mutate(id, &{%{&1 | health: 10}, :ok})
      tick(id)
      settle(id)
      regenerated = Characters.snapshot(id).health

      pid = pid_for(id)
      ref = Process.monitor(pid)
      GenServer.stop(pid, :normal)
      assert_receive {:DOWN, ^ref, :process, ^pid, _}, 1_000

      assert Store.load(id).health == regenerated
    end

    test "a hard kill loses the buffer and nothing else", %{id: id} do
      start_character(id)
      Characters.mutate(id, &{%{&1 | adena: 4242, health: 10}, :ok})
      tick(id)
      settle(id)
      assert Characters.snapshot(id).health > 10, "the tick did not regenerate"

      # :kill is not catchable, so `terminate/2` never runs — power loss, the OOM killer, SIGKILL.
      pid = pid_for(id)
      ref = Process.monitor(pid)
      Process.exit(pid, :kill)
      assert_receive {:DOWN, ^ref, :process, ^pid, :killed}, 1_000

      reloaded = Store.load(id)

      assert reloaded.adena == 4242, "an action was lost, which the policy forbids"
      assert reloaded.health == 10, "buffered regeneration survived, so it was never buffered"
    end
  end

  describe "a database that will not take the write" do
    test "leaves the process alive and the state still owed", %{id: id} do
      start_character(id)
      pid = pid_for(id)

      # The character is one JSON document, so there is no column to overflow. A name that is not
      # valid UTF-8 cannot be encoded, and raises where any database error would.
      Characters.mutate(id, &{%{&1 | name: <<0xFF, 0xFE>>}, :ok})

      assert Process.alive?(pid), "a failed write killed the character and took its buffer"
      assert Characters.snapshot(id).name == <<0xFF, 0xFE>>
      assert Store.load(id).name == "Hero", "the failed write reached the database after all"
      assert :sys.get_state(pid).dirty_since != nil, "the state is not still owed"
    end
  end
end
