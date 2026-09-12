defmodule MiniLineage.BattleLogTest do
  @moduledoc """
  Every fight a character has had, and what becomes of them when the run ends.

  The log is the one thing here allowed to grow without limit, because it is append-only. What
  used to be delicate — claiming a run's fights for the board, discarding them when it was
  abandoned — is gone: a run is never reset in place, so its fights have exactly one owner for as
  long as they exist.
  """
  use MiniLineage.DataCase, async: false

  import Ecto.Query

  alias MiniLineage.{BattleLog, Characters}
  alias MiniLineage.Characters.{Record, Store}
  alias MiniLineage.Game.{Actions, Constants, Player}

  setup do
    session = Characters.new_session_id()
    on_exit(fn -> Characters.forget(session) end)

    {:ok, session: session}
  end

  defp start_character(session, race_id \\ 1) do
    Characters.mutate(session, fn player ->
      {player, _flash} = Player.initialize(player, Constants.race(race_id), "Hero")
      # Tanky enough to survive every fight below. A fatal fight does not count a battle, so
      # without this a lucky-unlucky roll would make these assertions come and go.
      {%{player | current_screen: "battle", health: 5_000}, :ok}
    end)
  end

  defp fight(session), do: Characters.mutate(session, &Actions.fight/1)

  defp rows(session) do
    case stored_id(session) do
      nil -> []
      id -> Repo.all(from e in BattleLog.Entry, where: e.character_id == ^id, order_by: e.id)
    end
  end

  describe "a fight" do
    test "is recorded with the numbers, not just the prose", %{session: session} do
      start_character(session)
      fight(session)

      [row] = rows(session)

      assert row.character_id == stored_id(session)
      assert is_integer(row.enemies_killed) and is_integer(row.xp_gained)
      assert is_boolean(row.is_critical) and is_boolean(row.ambushed)
      # The rendered lines ride alongside, so a log screen never has to re-roll the prose.
      assert is_binary(row.narrative["outcome_line"])
    end

    test "and the character it belongs to is written in the same breath", %{session: session} do
      start_character(session)
      fight(session)

      assert [row] = rows(session)
      assert stored(session).total_battles == 1, "a fight was logged that the character forgot"
      assert row.narrative["outcome_line"] != nil
    end

    test "appends rather than replacing, which is the whole point", %{session: session} do
      start_character(session)
      for _ <- 1..3, do: fight(session)

      assert length(rows(session)) == 3
      assert rows(session) == Enum.sort_by(rows(session), & &1.id)
    end
  end

  describe "the screen still shows the last one" do
    test "even though it is no longer in the character's document", %{session: session} do
      start_character(session)
      fight(session)
      remembered = Characters.snapshot(session).last_battle_narrative
      assert remembered != nil

      # Restarting the process is what proves it: the document has no narrative to reload.
      Characters.forget_process(session)

      assert Characters.snapshot(session).last_battle_narrative == remembered
    end
  end

  describe "the whole chronicle" do
    test "is every fight of one run, oldest first", %{session: session} do
      start_character(session)
      for _ <- 1..3, do: fight(session)

      history = BattleLog.history(stored_id(session))

      assert length(history) == 3
      assert Enum.all?(history, &is_binary(&1.narrative.outcome_line))
      # Oldest first: the page tells the run's story in the order it happened.
      assert Enum.map(history, & &1.outcome) ==
               Enum.map(
                 rows(session),
                 &%{
                   enemies_killed: &1.enemies_killed,
                   hp_lost: &1.hp_lost,
                   damage_blocked: &1.damage_blocked,
                   xp_gained: &1.xp_gained,
                   adena_gained: &1.adena_gained,
                   is_critical: &1.is_critical,
                   is_level_up: &1.is_level_up
                 }
               )
    end

    test "and nothing at all for a run that never drew a blade", %{session: session} do
      start_character(session)

      assert BattleLog.history(stored_id(session)) == []
    end
  end

  describe "when a run ends" do
    test "its fights stay with it, because the row itself stays", %{session: session} do
      start_character(session)
      fight(session)
      character_id = stored_id(session)

      Characters.mutate(session, &{%{&1 | dead: true, experience: 500, adena: 10}, :ok})
      Characters.archive(session)

      # Archived, not deleted: the run keeps its id, its fights and its place in the Halls, and
      # gives up only the session that tied it to a browser.
      assert Repo.get(Record, character_id)
      assert Repo.get(Record, character_id).session_id == nil

      assert Repo.all(from e in BattleLog.Entry, where: e.character_id == ^character_id) != []
    end

    test "and the next run cannot inherit them, because it is a different character", %{
      session: session
    } do
      start_character(session)
      fight(session)
      first = stored_id(session)

      Characters.mutate(session, &{%{&1 | dead: true}, :ok})
      Characters.archive(session)

      # A new session is what the browser gets back from /play-again.
      next = Characters.new_session_id()
      on_exit(fn -> Characters.forget(next) end)
      start_character(next)

      assert stored_id(next) != first
      assert rows(next) == [], "the next run inherited the previous one's fights"
      assert BattleLog.last_for(stored_id(next)) == nil
    end
  end

  describe "the foreign key" do
    test "takes a character's fights with it when the character does go", %{session: session} do
      # The only row still deleted is a visitor who never chose a race; this proves the cascade
      # that carries their fights, without depending on the sweep to produce one.
      start_character(session)
      fight(session)
      id = stored_id(session)
      assert rows(session) != []

      Store.delete(id)

      assert Repo.all(from e in BattleLog.Entry, where: e.character_id == ^id) == []
    end

    test "and refuses a fight belonging to no character at all" do
      orphan = BattleLog.row("no-such-character", sample_battle())

      # Ecto wraps the driver's error, so the constraint surfaces as a ConstraintError.
      assert_raise Ecto.ConstraintError, ~r/battle_log_character_id_fkey/, fn ->
        Repo.insert!(orphan)
      end
    end
  end

  defp sample_battle do
    %{
      outcome: %{
        enemies_killed: 1,
        hp_lost: 0,
        damage_blocked: 0,
        xp_gained: 1,
        adena_gained: 1,
        is_critical: false,
        is_level_up: false
      },
      narrative: %{outcome_line: "x"},
      ambushed: false,
      died: false,
      sound: nil
    }
  end
end
