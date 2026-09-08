defmodule MiniLineage.Game.DeathTest do
  @moduledoc """
  How a run ends. The death reason is fixed once, at the moment of death, so re-rendering the
  screen never re-rolls it — the same reasoning as the persisted battle narrative.
  """
  use ExUnit.Case, async: true

  alias MiniLineage.Game.{Actions, Constants, Narratives, Player, Rng}

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

  # The successful submission writes a row, so it lives in the database suite; these refusals are
  # refused by the guard before any write is attempted.
  test "cowards and cheaters may not write a legacy" do
    dead = Player.kill(living())

    for barred <- [%{dead | coward: true}, %{dead | cheated: true}] do
      assert {_p, {:error, :ineligible, _}} = Actions.submit_highscore(barred)
    end
  end

  test "and neither may the living" do
    assert {_p, {:error, :not_dead, _}} = Actions.submit_highscore(living())
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
