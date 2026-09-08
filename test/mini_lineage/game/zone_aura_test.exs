defmodule MiniLineage.Game.ZoneAuraTest do
  @moduledoc """
  The disengage countdown — the most intricate rule in the port, and the one nothing was checking.

  Leaving a combat zone does not rest you instantly: ⚔️ In Combat stays with a 5-second countdown,
  and only when that elapses does 💤 Resting take over. Standing in a combat zone keeps you flagged
  indefinitely with no countdown at all, so waiting on the Battleground never restores a point of
  health. The countdown is anchored to LEAVING, so stepping back in cancels it and stepping out
  again starts a fresh one.
  """
  use ExUnit.Case, async: true

  alias MiniLineage.Game.{Clock, Constants, Player}

  @now 1_700_000_000_000
  @linger 5_000

  setup do
    Clock.put_now(@now)
    {player, _} = Player.initialize(%Player{}, Constants.race(0), "Wanderer")

    {:ok, player: player}
  end

  defp aura(player), do: Enum.find(player.effects, &(&1.id in ["combat", "resting"]))

  defp move(player, screen) do
    {player, changed?} = Player.sync_zone_auras(%{player | current_screen: screen})
    {player, changed?}
  end

  test "standing in a combat zone flags you indefinitely, with no countdown", %{player: player} do
    for zone <- ~w(battle suicide death) do
      {moved, _} = move(player, zone)

      assert aura(moved).id == "combat"
      assert aura(moved).expires_at == nil, "#{zone} must not carry a countdown"
      assert moved.combat_until == nil
    end
  end

  test "a resting zone rests you", %{player: player} do
    for zone <- ~w(home inn weapons armors character highscores) do
      {moved, _} = move(player, zone)

      assert aura(moved).id == "resting", zone
    end
  end

  test "leaving a combat zone keeps you in combat, now counting down", %{player: player} do
    {player, _} = move(player, "battle")
    {player, changed?} = move(player, "home")

    assert changed?
    assert aura(player).id == "combat"
    assert aura(player).expires_at == @now + @linger
  end

  test "the countdown follows you anywhere, even a screen in neither zone", %{player: player} do
    {player, _} = move(player, "battle")
    {player, _} = move(player, "statistics")

    assert aura(player).id == "combat"
    assert aura(player).expires_at == @now + @linger
  end

  test "stepping back in cancels the countdown", %{player: player} do
    {player, _} = move(player, "battle")
    {player, _} = move(player, "home")
    assert aura(player).expires_at == @now + @linger

    {player, _} = move(player, "battle")

    assert aura(player).expires_at == nil
    assert player.combat_until == nil
  end

  test "stepping out again arms a FRESH countdown, anchored to leaving", %{player: player} do
    {player, _} = move(player, "battle")
    {player, _} = move(player, "home")
    {player, _} = move(player, "battle")

    # Time passes while standing in the zone; the new countdown must not inherit the old deadline.
    Clock.put_now(@now + 3_000)
    {player, _} = move(player, "home")

    assert aura(player).expires_at == @now + 3_000 + @linger
  end

  test "once it elapses, a resting zone finally rests you", %{player: player} do
    {player, _} = move(player, "battle")
    {player, _} = move(player, "home")

    Clock.put_now(@now + @linger + 1)
    {player, changed?} = move(player, "home")

    assert changed?
    assert aura(player).id == "resting"
    assert player.combat_until == nil
  end

  test "once it elapses, a screen in neither zone gets no aura at all", %{player: player} do
    {player, _} = move(player, "battle")
    {player, _} = move(player, "statistics")

    Clock.put_now(@now + @linger + 1)
    {player, _} = move(player, "statistics")

    assert aura(player) == nil
  end

  test "an ambush holds you in combat wherever you claim to be", %{player: player} do
    {player, _} = move(%{player | ambushed: true}, "inn")

    assert aura(player).id == "combat"
    assert aura(player).expires_at == nil, "an ambush is not a disengage"
  end

  test "the dead get no aura", %{player: player} do
    {player, _} = move(player, "battle")
    {player, _} = move(%{player | dead: true}, "battle")

    assert aura(player) == nil
  end

  test "reports no change when the aura is already right", %{player: player} do
    {player, changed?} = move(player, "home")
    assert changed?

    {_player, changed?} = move(player, "home")
    refute changed?, "an unchanged aura must not trigger a persist and a broadcast"
  end

  test "waiting on the Battleground never restores a point of health", %{player: player} do
    {player, _} = move(%{player | health: 10}, "battle")

    Clock.put_now(@now + 60_000)
    {player, healed?} = Player.process_regen_tick(player)

    refute healed?
    assert player.health == 10
  end
end
