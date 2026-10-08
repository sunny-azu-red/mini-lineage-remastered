defmodule MiniLineage.Game.FightPropertiesTest do
  @moduledoc """
  A fight for every roll of the dice. StreamData draws the rolls and `Rng.put_source/1` feeds them
  in, so each property holds for any fight rather than for the one a seed happens to give, which
  is how a dice-dependent rule is asserted without asserting on a roll.
  """
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias MiniLineage.Game.{Actions, Constants, Narrative, Player, Rng}

  property "a fatal fight pays nothing and keeps no fight, and a survived one counts once" do
    check all rolls <- dice(), before <- fighter() do
      {after_fight, _} = fight(before, rolls)
      kinds = Enum.map(after_fight.pending_events, & &1.kind)
      send(self(), {:died, after_fight.dead})

      if after_fight.dead do
        assert {after_fight.experience, after_fight.adena} == {before.experience, before.adena}
        assert after_fight.total_battles == before.total_battles
        assert after_fight.total_enemies_killed == before.total_enemies_killed
        assert after_fight.last_battle_narrative == nil
        assert "ending" in kinds and "fight" not in kinds
      else
        assert after_fight.total_battles == before.total_battles + 1
        assert "fight" in kinds and "ending" not in kinds
      end
    end

    # Both branches, or the property above proved half of itself.
    assert_received {:died, true}
    assert_received {:died, false}
  end

  property "every line a fight stores is told in the third person and voices closed" do
    check all rolls <- dice(), before <- fighter(), mine? <- boolean() do
      {after_fight, _} = fight(before, rolls)

      for line <- stored_lines(after_fight) do
        refute line =~ ~r/\byou(rs?|rself)?\b/i, "second person stored: #{line}"
        refute Narrative.voiced(line, mine?) =~ ~r/\{\w+\}/, "left open: #{line}"
      end
    end
  end

  defp fight(player, rolls) do
    Process.put(:rolls, rolls)

    Rng.put_source(fn ->
      [roll | rest] = Process.get(:rolls)
      Process.put(:rolls, rest ++ [roll])
      roll
    end)

    Actions.fight(player)
  end

  # Cycled, since a fight draws an unknown number of times. Integers scaled down, not `float/1`,
  # whose bounded generation grows with the size until a long run spends seconds per case.
  defp dice do
    integer(0..999_999) |> map(&(&1 / 1_000_000)) |> list_of(min_length: 1, max_length: 48)
  end

  # Low health as often as not, or a first fight is never fatal and the death branch goes unseen.
  defp fighter do
    gen all race <- member_of(Constants.races()),
            archetype <- member_of([:fighter, :mystic]),
            health <- one_of([integer(1..15), integer(16..400)]),
            experience <- integer(0..400_000),
            adena <- integer(0..50_000) do
      {player, _} = Player.initialize(%Player{}, race, archetype, "Prop")
      %{player | health: health, experience: experience, adena: adena, pending_events: []}
    end
  end

  # What the Chronicle reads. `fight_prompt` and `next_move` are stored too, but only as the owner's
  # own battle buttons, so they speak to the player and are not lines.
  defp stored_lines(player) do
    Enum.flat_map(player.pending_events, fn
      %{line: line} ->
        [line]

      %{battle: %{narrative: narrative}} ->
        for {key, line} <- narrative, String.ends_with?(to_string(key), "_line"), line, do: line

      _ ->
        []
    end)
  end
end
