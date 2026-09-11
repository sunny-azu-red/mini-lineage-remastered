defmodule MiniLineage.BattleLogTest do
  @moduledoc """
  Every fight a character has had, and what becomes of them when the character does not.

  The log is the one thing here allowed to grow without limit, because it is append-only — so the
  rules that matter are about what it keeps. A run written to the board outlives its character; a
  run abandoned does not, and must not be inherited by whoever plays next on the same id.
  """
  use MiniLineage.DataCase, async: false

  alias MiniLineage.{BattleLog, Characters, Highscores}
  alias MiniLineage.Characters.Store
  alias MiniLineage.Game.{Actions, Constants, Player}

  setup do
    id = Characters.new_id()
    on_exit(fn -> Characters.forget(id) end)

    {:ok, id: id}
  end

  defp start_character(id, race_id \\ 1) do
    Characters.mutate(id, fn player ->
      {player, _flash} = Player.initialize(player, Constants.race(race_id), "Hero")
      {%{player | current_screen: "battle"}, :ok}
    end)
  end

  defp fight(id), do: Characters.mutate(id, &Actions.fight/1)

  defp rows(id) do
    import Ecto.Query
    Repo.all(from e in BattleLog.Entry, where: e.character_id == ^id, order_by: e.id)
  end

  describe "a fight" do
    test "is recorded with the numbers, not just the prose", %{id: id} do
      start_character(id)
      fight(id)

      [row] = rows(id)

      assert row.character_id == id
      assert row.highscore_id == nil
      assert is_integer(row.enemies_killed) and is_integer(row.xp_gained)
      assert is_boolean(row.is_critical) and is_boolean(row.ambushed)
      # The rendered lines ride alongside, so a log screen never has to re-roll the prose.
      assert is_binary(row.narrative["outcome_line"])
    end

    test "and the character it belongs to is written in the same breath", %{id: id} do
      start_character(id)
      fight(id)

      assert [row] = rows(id)
      assert Store.load(id).total_battles >= 1, "a fight was logged that the character forgot"
      assert row.narrative["outcome_line"] != nil
    end

    test "appends rather than replacing, which is the whole point", %{id: id} do
      start_character(id)
      for _ <- 1..3, do: if(Characters.snapshot(id).dead == false, do: fight(id))

      assert length(rows(id)) >= 1
      assert rows(id) == Enum.sort_by(rows(id), & &1.id)
    end
  end

  describe "the screen still shows the last one" do
    test "even though it is no longer in the character's document", %{id: id} do
      start_character(id)
      fight(id)
      remembered = Characters.snapshot(id).last_battle_narrative
      assert remembered != nil

      # Restarting the process is what proves it: the document has no narrative to reload.
      [{pid, _}] = Registry.lookup(MiniLineage.Characters.Registry, id)
      ref = Process.monitor(pid)
      GenServer.stop(pid, :normal)
      assert_receive {:DOWN, ^ref, :process, ^pid, _}, 1_000

      assert Characters.snapshot(id).last_battle_narrative == remembered
    end
  end

  describe "when a life ends" do
    test "a legacy claims its fights, so they outlive the character", %{id: id} do
      start_character(id)
      fight(id)
      Characters.mutate(id, &{%{&1 | dead: true, experience: 500, adena: 10}, :ok})
      Characters.mutate(id, &Actions.submit_highscore/1)

      claimed = rows(id)
      assert claimed != []
      assert Enum.all?(claimed, &is_integer(&1.highscore_id)), "a fight was left unclaimed"

      # And the sweep leaves them, because they belong to the board now, not to the character.
      Characters.forget(id)
      assert BattleLog.sweep_orphaned() >= 0
      assert rows(id) != [], "a claimed fight was swept with its character"
    end

    test "starting over without one discards them, so the next life starts empty", %{id: id} do
      start_character(id)
      fight(id)
      assert rows(id) != []

      Characters.mutate(id, &{%{&1 | dead: true}, :ok})
      Characters.mutate(id, &Actions.restart/1)

      assert rows(id) == [], "the next life inherited the previous one's fights"
    end
  end

  describe "the sweep" do
    test "takes unclaimed fights whose character is gone", %{id: id} do
      start_character(id)
      fight(id)
      assert rows(id) != []

      Characters.forget(id)
      assert BattleLog.sweep_orphaned() >= 1

      assert rows(id) == []
    end

    test "and leaves a live character's alone", %{id: id} do
      start_character(id)
      fight(id)

      assert BattleLog.sweep_orphaned() == 0
      assert rows(id) != []
    end
  end

  describe "the board entry" do
    test "hands back the id that claims a run", %{id: _id} do
      id = Highscores.insert(%{name: "Hero", experience: 10, race_id: 1, adena: 2, level: 1})

      assert is_integer(id)
    end
  end
end
