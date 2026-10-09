defmodule MiniLineage.Game.NightTest do
  @moduledoc """
  Rules §15 and §16 on a character: night costs every race 3 Accuracy, and only a Dark Elf's
  Shadow Sense gives it back. Each is an aura carrying its modifier, so what changes the stat is
  what the header shows. The clock is pinned, so no assertion here depends on the hour it runs.
  """
  use ExUnit.Case, async: true

  alias MiniLineage.Game.{Clock, Constants, Player, Snapshot}

  @day ~U[2026-07-01 09:00:00Z]
  @night ~U[2026-07-01 20:00:00Z]

  defp born(race_id) do
    {player, _} = Player.initialize(%Player{}, Constants.race(race_id), :fighter, "Watcher")
    player
  end

  defp at(time, fun) do
    Clock.put_now(time)
    fun.()
  end

  defp aura_ids(player), do: Enum.map(Player.auras(player), & &1.id)

  test "by day nothing is put on anybody" do
    for race_id <- 0..3 do
      assert at(@day, fn -> aura_ids(born(race_id)) end) == ["resting"]
    end
  end

  test "at night every race shows the night, and only a Dark Elf its Shadow Sense" do
    for race_id <- 0..3 do
      ids = at(@night, fn -> aura_ids(born(race_id)) end)

      assert "night" in ids
      assert "shadow_sense" in ids == (race_id == 3), inspect(ids)
    end
  end

  test "a Dark Elf keeps its daytime Accuracy at night, and every other race loses 3" do
    for race_id <- 0..3 do
      player = born(race_id)
      day = at(@day, fn -> Player.stats(player).accuracy end)
      night = at(@night, fn -> Player.stats(player).accuracy end)

      expected = if race_id == 3, do: day, else: day - 3
      assert night == expected, "race #{race_id}: #{day} by day, #{night} at night"
    end
  end

  test "and nothing else the rules give it moves" do
    player = born(0)
    day = at(@day, fn -> Player.stats(player) end)
    night = at(@night, fn -> Player.stats(player) end)

    assert Map.delete(night, :accuracy) == Map.delete(day, :accuracy)
  end

  test "the header says what each one changes" do
    tooltips =
      at(@night, fn -> Snapshot.build(born(3)).effects end)
      |> Map.new(&{&1.id, &1.tooltip})

    assert tooltips["night"] == "Night (-3 Accuracy)"
    assert tooltips["shadow_sense"] == "Shadow Sense (+3 Accuracy)"
  end
end
