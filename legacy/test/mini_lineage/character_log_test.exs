defmodule MiniLineage.CharacterLogTest do
  @moduledoc """
  Every fight a character has had, and what becomes of them when the run ends.

  The log is append-only, so it is the one thing here allowed to grow without limit. A run is never
  reset in place, so its fights have exactly one owner for as long as they exist.
  """
  use MiniLineage.DataCase, async: false

  import Ecto.Query

  alias MiniLineage.{CharacterLog, Characters}
  alias MiniLineage.Characters.{Record, Store}
  alias MiniLineage.Game.{Actions, Clock, Constants, Player}

  setup do
    session = Characters.new_session_id()
    on_exit(fn -> Characters.forget(session) end)

    {:ok, session: session}
  end

  defp start_character(session, race_id \\ 1) do
    Characters.mutate(session, fn player ->
      {player, _flash} = Player.initialize(player, Constants.race(race_id), :fighter, "Hero")
      {%{player | current_screen: "battle"}, :ok}
    end)

    # A fatal fight does not count a battle, so an unlucky roll would make these come and go.
    pin_dice(session)
  end

  defp fight(session), do: Characters.mutate(session, &Actions.fight/1)

  # The newest page, which is every entry a run as short as these has, put back in the order it
  # happened: the Chronicle reads newest first, and these claims are about what came after what.
  defp recent(id), do: id |> CharacterLog.page() |> elem(0) |> Enum.reverse()

  # The table holds every deed, so a claim about fighting says so.
  defp fights(session), do: Enum.filter(rows(session), &(&1.kind == "fight"))

  defp rows(session) do
    case stored_id(session) do
      nil -> []
      id -> Repo.all(from e in CharacterLog.Entry, where: e.character_id == ^id, order_by: e.id)
    end
  end

  describe "a fight" do
    test "is recorded as the lines it was told in", %{session: session} do
      start_character(session)
      fight(session)

      [row] = fights(session)

      assert row.character_id == stored_id(session)
      # Every line by name, a line that did not happen as nil, so a log never re-rolls the prose.
      assert row.narrative |> Map.keys() |> Enum.sort() ==
               Enum.sort(~w(crit_line kill_line deflection_line outcome_line next_move))

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

  # `Server.init/1` rebuilds the battle screen from `last_for/1`: without the kind in the query, a
  # last deed that was a purchase reconnects to a battle report that renders blank.
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

  # A watcher appends its chronicle on the strength of this push: a purchase moves neither the
  # battle count nor the last fight, so the tallies cannot say a row was written.
  describe "a deed reaching a watcher" do
    test "says a row was written, for a purchase as much as a fight", %{session: session} do
      start_character(session)
      Characters.mutate(session, fn p -> {%{p | adena: 100_000}, :ok} end)
      id = stored_id(session)
      Phoenix.PubSub.subscribe(MiniLineage.PubSub, Characters.record_topic(id))

      {result, _} = Characters.mutate(session, &Actions.purchase(&1, "weapon", 1))

      assert match?({:ok, %{type: :success}}, result),
             "the purchase did not happen: #{inspect(result)}"

      assert_receive {:record_updated, _player, ^id, true}

      Characters.mutate(session, &Actions.fight/1)
      assert_receive {:record_updated, _player, ^id, true}
    end

    # Nobody acts when a buff lapses, but its row is for the log, so it is written, not buffered.
    test "says so when a buff lapses on its own, with nobody acting", %{session: session} do
      start_character(session)
      id = stored_id(session)

      # Before the mutate: once the blessing is overdue, its own expiry timer may lapse it at once.
      Phoenix.PubSub.subscribe(MiniLineage.PubSub, Characters.record_topic(id))

      Characters.mutate(session, fn p ->
        {%{p | effects: Enum.map(p.effects, &overdue/1)}, :ok}
      end)

      Characters.snapshot(session)

      assert_receive {:record_updated, _player, ^id, true}
      assert Enum.any?(recent(id), &(&1.kind == "buff" and &1.line =~ "leaves"))
    end
  end

  # An effect leaves by its timer, by the run ending, or by a meal replacing a meal: each is told.
  describe "an effect that ends before its time" do
    test "fades with the run, in the order it arrived, just before the ending", %{
      session: session
    } do
      start_character(session)
      Characters.mutate(session, fn p -> {%{p | adena: 100_000}, :ok} end)
      Characters.mutate(session, &Actions.purchase(&1, "food", 2))

      # The clock moves between the ending and the logging of what faded with it, so a line dated
      # when it was noticed cannot pass for one dated with the end.
      ended_at = System.system_time(:millisecond) + 1_000

      Characters.mutate(session, fn p ->
        Clock.put_now(ended_at)
        # The ending a fatal fight writes, without a fight's dice to decide whether it is fatal.
        p = Player.kill(p)
        result = {Player.log(p, Player.event("ending", p.death_reason)), {:ok, nil}}
        Clock.put_now(ended_at + 60_000)
        result
      end)

      log = recent(stored_id(session))
      [blessing, meal, ending] = Enum.take(log, -3)

      assert ending.kind == "ending"
      assert blessing.line =~ "Newbie Blessing" and blessing.line =~ "last breath"
      assert meal.line =~ "Satisfied" and meal.line =~ "last breath"
      # Simultaneous with the end, and dated so: the log stays in time order.
      assert ending.at == Clock.to_datetime(ended_at)
      assert blessing.at == ending.at and meal.at == ending.at
    end

    test "and a fatal fight is logged as the ending it is", %{session: session} do
      start_character(session)
      fight(session)
      # A fight costs at least 1 HP whatever the dice say, so this one is fatal.
      Characters.mutate(session, &{%{&1 | health: 1}, :ok})
      fight(session)

      [blessing, ending] = Enum.take(recent(stored_id(session)), -2)

      # Stored with the pronoun open, like every line in the log.
      assert blessing.line =~ "Newbie Blessing" and
               blessing.line =~ "fades with {their} last breath"

      # Its other lines were dropped when it turned fatal; how it ended is all that is left.
      assert ending.kind == "ending"
      assert ending.line == Characters.snapshot(session).death_reason
      assert length(fights(session)) == 1

      # Nothing of that fight is kept, and a restart does not bring back the one before it either:
      # no screen a dead run can reach shows a fight.
      assert Characters.snapshot(session).last_battle_narrative == nil
      Characters.forget_process(session)
      assert Characters.snapshot(session).last_battle_narrative == nil
    end

    test "and is stored as the buff or debuff it is",
         %{session: session} do
      start_character(session)

      # The game has no debuff of its own today, so the test brings one.
      curse = %{id: "test_curse", type: :debuff, emoji: "🧪", label: "Cursed", modifiers: []}

      Characters.mutate(
        session,
        &{Player.apply_effect(&1, Map.put(curse, :duration_ms, 60_000)), :ok}
      )

      kinds = stored_id(session) |> recent() |> Enum.map(& &1.kind)

      assert "buff" in kinds and "debuff" in kinds
    end

    test "and a meal that replaces a meal says the first one left", %{session: session} do
      start_character(session)
      Characters.mutate(session, fn p -> {%{p | adena: 100_000}, :ok} end)
      Characters.mutate(session, &Actions.purchase(&1, "food", 2))
      Characters.mutate(session, &Actions.purchase(&1, "food", 3))

      [ate, left, settled] =
        stored_id(session) |> recent() |> Enum.take(-3) |> Enum.map(& &1.line)

      assert ate =~ "Hearty Mash"
      assert left =~ "Satisfied" and left =~ "leaves"
      assert settled =~ "Well Fed" and settled =~ "settles"
    end
  end

  defp overdue(%{id: "newbie_blessing"} = effect), do: %{effect | expires_at: 1}
  defp overdue(effect), do: effect

  describe "the whole chronicle" do
    test "is every fight of one run, oldest first", %{session: session} do
      start_character(session)
      for _ <- 1..3, do: fight(session)

      history = recent(stored_id(session))

      assert length(Enum.filter(history, &(&1.kind == "fight"))) == 3

      assert Enum.all?(
               Enum.filter(history, &(&1.kind == "fight")),
               &is_binary(&1.narrative.outcome_line)
             )

      # Oldest first: the page tells the run's story in the order it happened.
      assert history |> Enum.filter(&(&1.kind == "fight")) |> Enum.map(& &1.id) ==
               Enum.map(fights(session), & &1.id)
    end

    test "and only its beginning for a run that never drew a blade", %{session: session} do
      start_character(session)

      # The blessing it is born with is a deed done to it, so it is told like any other.
      assert [%{kind: "start", number: 1}, %{kind: "buff", number: 2}] =
               recent(stored_id(session))

      assert fights(session) == []
    end

    # The newest end, because that is the end a reader is looking at; the whole history would
    # otherwise go through the socket on every page load.
    test "is capped at the window, and it is the newest end", %{session: session} do
      start_character(session)
      for _ <- 1..5, do: fight(session)

      id = stored_id(session)
      all = Enum.map(rows(session), & &1.id)
      {windowed, true} = CharacterLog.page(id, nil, 3)

      assert length(windowed) == 3
      assert Enum.map(windowed, & &1.id) == all |> Enum.take(-3) |> Enum.reverse()
    end

    test "and a reader already holding some asks only for what came after", %{session: session} do
      start_character(session)
      for _ <- 1..3, do: fight(session)

      id = stored_id(session)
      {[newest | _], true} = CharacterLog.page(id, nil, 2)
      cursor = newest.id

      fight(session)
      added = CharacterLog.since(id, cursor, newest.number)

      # Counted by kind: the fight may cross a level, which the dice decide, and log its own row.
      assert Enum.count(added, &(&1.kind == "fight")) == 1
      assert Enum.all?(added, &(&1.id > cursor))
      # Numbered on from the newest held, however many rows the dice made of it.
      assert Enum.map(added, & &1.number) ==
               Enum.to_list((newest.number + length(added))..(newest.number + 1)//-1)
    end

    # Nothing has been written since, so there is nothing to append and no reason to have asked.
    test "and nothing when the cursor is already the last of them", %{session: session} do
      start_character(session)
      fight(session)

      id = stored_id(session)

      last = List.last(recent(id))
      assert CharacterLog.since(id, last.id, last.number) == []
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
      # Nothing in the game deletes a row, so the cascade is proved by deleting one directly.
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

  defp sample_battle, do: %{narrative: %{outcome_line: "x"}, at: DateTime.utc_now()}
end
