defmodule MiniLineage.Characters.TickLogTest do
  @moduledoc "The one line the tick writes per firing, at :debug."
  use MiniLineage.DataCase, async: false

  alias MiniLineage.Characters
  alias MiniLineage.Game.{Constants, Player}

  setup do
    id = Characters.new_session_id()
    on_exit(fn -> Characters.forget(id) end)
    hold(id)

    {:ok, id: id}
  end

  defp start(id, race_id, overrides \\ %{}) do
    Characters.mutate(id, fn player ->
      {player, _} = Player.initialize(player, Constants.race(race_id), :fighter, "Logged")
      {Map.merge(player, overrides), :ok}
    end)
  end

  defp tick(id) do
    [{pid, _}] = Registry.lookup(MiniLineage.Characters.Registry, id)

    capture_debug(fn ->
      send(pid, :tick)
      # One round trip, so the tick has certainly been handled before the capture stops.
      Characters.snapshot(id)
    end)
  end

  test "a wounded character regenerates and says by how much", %{id: id} do
    start(id, 2, %{health: 40})

    # An Elven Fighter rests 1.55 × 0.90 × 1.28 for CON 36 × 3 = 5.4 a tick (rules §11).
    assert tick(id) =~ "HP: 40 -> 45/113 | MP: 39/39 (+5 HP)"
  end

  test "the hardiest Fighter mends the most, at its own rate", %{id: id} do
    # CON 47 is the highest any Fighter is born with: 7.4 a tick against the Elf's 5.4.
    start(id, 1, %{health: 40})

    assert tick(id) =~ "(+7 HP)"
  end

  test "mana mends alongside it, and says so too", %{id: id} do
    start(id, 2, %{health: 40, mp: 10})

    assert tick(id) =~ "HP: 40 -> 45/113 | MP: 10 -> 13/39 (+5 HP, +3 MP)"
  end

  test "a character at full health says so", %{id: id} do
    start(id, 2)

    assert tick(id) =~ "(Full)"
  end

  test "a visitor who has not created a character is not described at all", %{id: id} do
    # No health and nothing to mend: every field the line reads is still nil.
    refute tick(id) =~ "[TICK:"
  end
end
