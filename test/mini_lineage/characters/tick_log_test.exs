defmodule MiniLineage.Characters.TickLogTest do
  @moduledoc """
  The one line the tick writes per firing. Its zone reads the RESTING aura rather than the absence
  of combat — a screen in neither zone list is its own case, not a "Resting" logged next to a tick
  that regenerated nothing.
  """
  use MiniLineage.DataCase, async: false

  import ExUnit.CaptureLog

  require Logger

  alias MiniLineage.Characters
  alias MiniLineage.Game.{Constants, Player}

  setup do
    # The test environment silences everything below :warning, and the line under test is a debug.
    previous = Logger.level()
    Logger.configure(level: :debug)
    on_exit(fn -> Logger.configure(level: previous) end)

    id = Characters.new_id()
    on_exit(fn -> Characters.forget(id) end)
    hold(id)

    Characters.mutate(id, fn player ->
      {player, _} = Player.initialize(player, Constants.race(2), "Logged")
      {player, :ok}
    end)

    {:ok, id: id}
  end

  defp tick(id) do
    [{pid, _}] = Registry.lookup(MiniLineage.Characters.Registry, id)

    capture_log([level: :debug], fn ->
      send(pid, :tick)
      # One round trip, so the tick has certainly been handled before the capture stops.
      Characters.snapshot(id)
    end)
  end

  defp move(id, screen, overrides \\ %{}) do
    Characters.mutate(id, fn player ->
      {player, _} =
        Player.sync_zone_auras(Map.merge(%{player | current_screen: screen}, overrides))

      {player, :ok}
    end)
  end

  test "a resting, wounded character regenerates and says by how much", %{id: id} do
    move(id, "home", %{health: 40})

    log = tick(id)
    assert log =~ "Resting"
    assert log =~ "40 -> 43/95"
    assert log =~ "(+3 HPR)"
  end

  test "standing in a combat zone is paused, not resting", %{id: id} do
    move(id, "battle", %{health: 40})

    log = tick(id)
    assert log =~ "In Combat"
    assert log =~ "(Paused)"
  end

  test "a screen in neither zone list is its own case", %{id: id} do
    # Reached by disengaging and letting the countdown lapse somewhere that rests nobody.
    move(id, "battle", %{health: 40})
    move(id, "statistics")

    Characters.mutate(
      id,
      &{%{&1 | combat_until: 0, effects: Enum.reject(&1.effects, fn e -> e.id == "combat" end)},
       :ok}
    )

    move(id, "statistics")

    log = tick(id)
    assert log =~ "No Zone", "not 'Resting' — regeneration is off here"
    assert log =~ "(Paused)"
  end

  test "a character at full health says so", %{id: id} do
    move(id, "home")

    assert tick(id) =~ "(Full)"
  end

  test "the dead are dead", %{id: id} do
    Characters.mutate(id, &{Player.kill(&1), :ok})

    log = tick(id)
    assert log =~ "Dead"
    assert log =~ "(Paused)"
  end

  test "a race with no regeneration is idle rather than mid-heal", %{id: _id} do
    orc = Characters.new_id()
    on_exit(fn -> Characters.forget(orc) end)
    hold(orc)

    Characters.mutate(orc, fn player ->
      {player, _} = Player.initialize(player, Constants.race(1), "Grok")
      {player, _} = Player.sync_zone_auras(%{player | current_screen: "home", health: 40})
      {player, :ok}
    end)

    log = tick(orc)
    assert log =~ "Resting"
    assert log =~ "(0 HPR)"
  end

  test "a visitor who has not created a character is not described at all" do
    visitor = Characters.new_id()
    on_exit(fn -> Characters.forget(visitor) end)
    hold(visitor)

    # No health, no zone, nothing expiring: the tick has nothing true to say about a visitor, and
    # every field the line reads is still nil.
    refute tick(visitor) =~ "[TICK:"
  end
end
