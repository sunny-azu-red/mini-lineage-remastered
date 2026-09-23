defmodule MiniLineage.CharacterLogTest do
  @moduledoc """
  Every fight a character has had, and what becomes of them when the run ends.

  The log is the one thing here allowed to grow without limit, because it is append-only. What
  used to be delicate — claiming a run's fights for the board, discarding them when it was
  abandoned — is gone: a run is never reset in place, so its fights have exactly one owner for as
  long as they exist.
  """
  use MiniLineage.DataCase, async: false

  import Ecto.Query

  alias MiniLineage.{CharacterLog, Characters}
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

  # The table holds every deed now, so a claim about fighting says so rather than counting whatever
  # the run happened to do.
  defp fights(session), do: Enum.filter(rows(session), &(&1.kind == "fight"))

  defp rows(session) do
    case stored_id(session) do
      nil -> []
      id -> Repo.all(from e in CharacterLog.Entry, where: e.character_id == ^id, order_by: e.id)
    end
  end

  describe "a fight" do
    test "is recorded with the numbers, not just the prose", %{session: session} do
      start_character(session)
      fight(session)

      [row] = fights(session)

      assert row.character_id == stored_id(session)
      assert is_integer(row.enemies_killed) and is_integer(row.xp_gained)
      assert is_boolean(row.is_critical) and is_boolean(row.ambushed)
      # The rendered lines ride alongside, so a log screen never has to re-roll the prose.
      assert is_binary(row.narrative["outcome_line"])
    end

    test "and the character it belongs to is written in the same breath", %{session: session} do
      start_character(session)
      fight(session)

      assert [row] = fights(session)
      assert stored(session).total_battles == 1, "a fight was logged that the character forgot"
      assert row.narrative["outcome_line"] != nil
    end

    test "appends rather than replacing, which is the whole point", %{session: session} do
      start_character(session)
      for _ <- 1..3, do: fight(session)

      assert length(fights(session)) == 3
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

  # `Server.init/1` rebuilds the battle screen from `last_for/1`. The table holds more than fights
  # now, so without the kind in the query a player whose last deed was a purchase reconnects to a
  # battle report with no lines and no numbers — which renders blank rather than failing.
  describe "the last fight" do
    test "is the last FIGHT, not the last thing that happened", %{session: session} do
      start_character(session)
      fight(session)
      fought = CharacterLog.last_for(stored_id(session))

      Repo.insert!(%CharacterLog.Entry{
        character_id: stored_id(session),
        kind: "purchase",
        narrative: %{"line" => "bought a blade"},
        inserted_at: DateTime.utc_now()
      })

      assert CharacterLog.last_for(stored_id(session)) == fought
    end
  end

  describe "the whole chronicle" do
    test "is every fight of one run, oldest first", %{session: session} do
      start_character(session)
      for _ <- 1..3, do: fight(session)

      history = CharacterLog.recent(stored_id(session))

      assert length(Enum.filter(history, &(&1.kind == "fight"))) == 3

      assert Enum.all?(
               Enum.filter(history, &(&1.kind == "fight")),
               &is_binary(&1.narrative.outcome_line)
             )

      # Oldest first: the page tells the run's story in the order it happened.
      assert history |> Enum.filter(&(&1.kind == "fight")) |> Enum.map(& &1.outcome) ==
               Enum.map(
                 fights(session),
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

    test "and only its beginning for a run that never drew a blade", %{session: session} do
      start_character(session)

      assert [%{kind: "start"}] = CharacterLog.recent(stored_id(session))
      assert fights(session) == []
    end

    # The whole history of a long run went through the socket on every page load to fill a 260px
    # box. The window is the newest end of it, because that is the end a reader is looking at.
    test "is capped at the window, and it is the newest end", %{session: session} do
      start_character(session)
      for _ <- 1..5, do: fight(session)

      id = stored_id(session)
      all = Enum.map(rows(session), & &1.id)
      windowed = CharacterLog.recent(id, 3)

      assert length(windowed) == 3
      assert Enum.map(windowed, & &1.id) == Enum.take(all, -3)
    end

    test "and a reader already holding some asks only for what came after", %{session: session} do
      start_character(session)
      for _ <- 1..3, do: fight(session)

      id = stored_id(session)
      held = CharacterLog.recent(id, 2)
      cursor = List.last(held).id

      fight(session)
      added = CharacterLog.since(id, cursor)

      assert length(added) == 1
      assert hd(added).id > cursor
    end

    # Nothing has been written since, so there is nothing to append and no reason to have asked.
    test "and nothing when the cursor is already the last of them", %{session: session} do
      start_character(session)
      fight(session)

      id = stored_id(session)

      assert CharacterLog.since(id, List.last(CharacterLog.recent(id)).id) == []
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

      assert Repo.all(from e in CharacterLog.Entry, where: e.character_id == ^character_id) != []
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
      assert fights(next) == [], "the next run inherited the previous one's fights"
      assert CharacterLog.last_for(stored_id(next)) == nil
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

      assert Repo.all(from e in CharacterLog.Entry, where: e.character_id == ^id) == []
    end

    test "and refuses a fight belonging to no character at all" do
      orphan = CharacterLog.row("no-such-character", sample_battle())

      # Ecto wraps the driver's error, so the constraint surfaces as a ConstraintError.
      assert_raise Ecto.ConstraintError, ~r/character_log_character_id_fkey/, fn ->
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
      sound: nil,
      at: DateTime.utc_now()
    }
  end
end
