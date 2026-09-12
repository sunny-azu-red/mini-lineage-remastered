defmodule MiniLineage.Game.DeathTest do
  @moduledoc """
  How a run ends. The death reason is fixed once, at the moment of death, so re-rendering the
  screen never re-rolls it — the same reasoning as the persisted battle narrative.
  """
  use ExUnit.Case, async: true

  alias MiniLineage.Game.{Actions, Constants, Narratives, Player, Rng, Snapshot}

  defp living do
    {player, _} = Player.initialize(%Player{}, Constants.race(0), "Doomed")
    player
  end

  test "dying empties the character: no health, no effects, and a reason" do
    player = Player.kill(living())

    assert player.dead
    assert player.health == 0
    assert player.effects == []
    assert player.death_reason in Narratives.death()
  end

  test "a coward gets the coward's line, not a random one" do
    player = Player.commit_suicide(living())

    assert player.coward
    assert player.death_reason == "🤡 You took the cowardly way out."
  end

  test "a cheater's line outranks the coward's" do
    player = Player.commit_suicide(%{living() | cheated: true})

    assert player.death_reason =~ "heresy"
  end

  test "the reason is fixed at the moment of death and never re-rolled" do
    player = Player.kill(living())
    reason = player.death_reason

    # Every later pass must leave it alone, however many times the screen re-renders.
    for _ <- 1..20, do: assert(Player.resolve_death_reason(player).death_reason == reason)
  end

  test "a fatal blow awards nothing — a corpse cannot loot" do
    player = %{living() | health: 5, adena: 100, experience: 50, total_battles: 3}

    outcome = %{
      enemies_killed: 9,
      hp_lost: 999,
      damage_blocked: 1,
      xp_gained: 500,
      adena_gained: 500,
      is_critical: false,
      is_level_up: false
    }

    {dead, level_up?} = Player.resolve_battle_outcome(player, outcome)

    refute level_up?
    assert dead.dead
    assert dead.adena == 100, "no adena from the fight that killed you"
    assert dead.experience == 50, "no experience either"
    assert dead.total_battles == 3, "and it does not count as a battle fought"
  end

  # Nobody writes a legacy any more: a run is in the Halls from the moment it picks a race. What is
  # left to decide is who is barred, and that is now a property of the run rather than of an action.
  test "cowards and cheaters are barred from the Halls, alive or dead" do
    dead = Player.kill(living())

    for barred <- [%{dead | coward: true}, %{dead | cheated: true}] do
      assert Snapshot.build(barred).disqualified
    end
  end

  test "and an ordinary run, living or finished, is not" do
    refute Snapshot.build(living()).disqualified
    refute Snapshot.build(Player.kill(living())).disqualified
  end

  test "a new character remembers no fight, whatever the struct it is built on" do
    # `initialize/3` overwrites a %Player{} that may have been rehydrated from storage, so every
    # field carried over from the previous run has to be named here or it survives the reroll.
    fought = %{living() | last_battle_narrative: %{narrative: %{}, outcome: %{}}}
    {fresh, _} = Player.initialize(fought, Constants.race(1), "Second")

    assert fresh.last_battle_narrative == nil
    assert fresh.total_battles == 0
  end

  test "only the fallen may start over — a living character can never be wiped" do
    assert {player, {:error, :not_dead, _}} = Actions.restart(living())
    assert player.name == "Doomed"

    assert {fresh, {:ok, nil}} = Actions.restart(%{living() | dead: true})
    assert fresh == %Player{}
  end

  test "every death message is drawn from the table, never invented" do
    for seed <- 1..40 do
      Rng.put_source(fn -> rem(seed * 7, 100) / 100 end)
      assert Player.kill(living()).death_reason in Narratives.death()
    end
  end
end
