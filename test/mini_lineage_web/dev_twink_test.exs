defmodule MiniLineageWeb.DevTwinkTest do
  @moduledoc """
  Typing `twink` in a debug build puts a run back to one saved state however often it is typed:
  Level 15, every lesson its trainer teaches by then, the best its village's traders sell its set in
  every weapon line, 30 potions, 10,000 SP and 50,000 Adena. Not async: a release is a flip of the
  debug build.
  """
  use MiniLineageWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import MiniLineage.DataCase, only: [stored: 1]

  alias MiniLineage.Characters
  alias MiniLineage.Game.{Actions, Math, Player}

  defp started(conn, race_id, path) do
    session = Characters.new_session_id()
    on_exit(fn -> Characters.forget(session) end)
    {:ok, view, _html} = conn |> init_test_session(%{"session_id" => session}) |> live(~p"/")

    view
    |> element("form[phx-submit=start]")
    |> render_submit(%{"name" => "Twink", "race_id" => race_id, "path" => path})

    {view, session}
  end

  defp type(view, letters) do
    for <<letter <- letters>>, do: render_hook(view, "key", %{"key" => <<letter>>})
    render(view)
  end

  defp gear(player) do
    {for(i <- player.items, i.equipped, do: i.name) |> Enum.sort(),
     for(i <- player.items, !i.equipped, do: i.name) |> Enum.sort()}
  end

  test "a Human Fighter gets every weapon line, the one-handed sword and shield in hand", %{
    conn: conn
  } do
    {view, session} = started(conn, "0", "fighter")

    assert type(view, "twink") =~ "Level 15"
    assert has_element?(view, "#levelled.alert-triumph", "You have reached Level 15.")
    player = stored(session)
    stats = Player.stats(player)

    assert player.experience == Math.xp_for_level(15)
    assert player.adena == 50_000
    assert player.sp == 10_000

    assert player.skills == %{
             "Power Strike" => 4,
             "Mortal Blow" => 4,
             "Power Shot" => 4,
             "Armor Mastery" => 3,
             "Weapon Mastery" => 3,
             "Anti Magic" => 2
           }

    assert {player.health, player.mp} == {stats.max_hp, stats.max_mp}

    assert gear(player) ==
             {[
                "Bone Breastplate",
                "Bone Gaiters",
                "Long Sword",
                "Necklace of Wisdom",
                "Round Shield"
              ], ["Forest Bow", "Lesser Healing Potion", "Throwing Knife", "Zweihander"]}

    assert %{count: 30} = Enum.find(player.items, &(&1.name == "Lesser Healing Potion"))
  end

  test "a set with only two-handed weapons gets no shield", %{conn: conn} do
    {view, session} = started(conn, "2", "fighter")
    type(view, "twink")

    assert gear(stored(session)) ==
             {["Bone Breastplate", "Bone Gaiters", "Forest Bow", "Necklace of Wisdom"],
              ["Lesser Healing Potion"]}
  end

  test "an Orc Fighter fights with its fists, a sword and shield carried", %{conn: conn} do
    {view, session} = started(conn, "1", "fighter")
    type(view, "twink")

    assert gear(stored(session)) ==
             {["Bone Breastplate", "Bone Gaiters", "Cestus", "Necklace of Wisdom"],
              ["Lesser Healing Potion", "Long Sword", "Round Shield", "Zweihander"]}
  end

  test "a mystic holds the one-handed staff and the shield, the two-handed one carried", %{
    conn: conn
  } do
    {view, session} = started(conn, "3", "mystic")
    type(view, "twink")

    assert gear(stored(session)) ==
             {[
                "Necklace of Wisdom",
                "Relic of The Saints",
                "Round Shield",
                "Stockings of Devotion",
                "Tunic of Devotion"
              ], ["Journeyman's Staff", "Lesser Healing Potion"]}
  end

  test "typed again it restores the same state, giving back only the piece that went", %{
    conn: conn
  } do
    {view, session} = started(conn, "0", "fighter")
    type(view, "twink")
    first = stored(session)
    knife = Enum.find(first.items, &(&1.name == "Throwing Knife"))
    sword = Enum.find(first.items, &(&1.name == "Zweihander"))

    {{:ok, _}, _} = Characters.mutate(session, &Actions.destroy(&1, knife.id))
    {{:ok, _}, _} = Characters.mutate(session, &Actions.equip(&1, sword.id))
    {{:ok, nil}, _} = Characters.mutate(session, &Actions.potion_at(&1, 0))

    {{:ok, nil}, %{unused: ["Power Strike"]}} =
      Characters.mutate(session, &Actions.use_skill(&1, "Power Strike", false))

    type(view, "maxlvl")
    type(view, "adena")
    type(view, "sp")

    type(view, "twink")
    again = stored(session)

    assert Map.take(again, [:experience, :skills, :sp, :adena]) ==
             Map.take(first, [:experience, :skills, :sp, :adena])

    assert Map.take(again, Map.keys(Player.default_orders())) == Player.default_orders()
    assert gear(again) == gear(first)
    assert length(again.items) == length(first.items)
    assert %{count: 30} = Enum.find(again.items, &(&1.name == "Lesser Healing Potion"))

    # Everything that stayed keeps its id: only the knife is new.
    kept = MapSet.new(first.items, & &1.id)
    assert [%{name: "Throwing Knife"}] = Enum.reject(again.items, &(&1.id in kept))
  end

  test "a release never listens for it, nor answers it" do
    previous = Application.fetch_env!(:mini_lineage, :debug_build)
    Application.put_env(:mini_lineage, :debug_build, false)
    on_exit(fn -> Application.put_env(:mini_lineage, :debug_build, previous) end)

    {view, session} = started(build_conn(), "0", "fighter")
    before = stored(session)

    type(view, "twink")

    assert stored(session) |> Map.take([:experience, :adena, :items]) ==
             Map.take(before, [:experience, :adena, :items])

    {result, player} = Characters.mutate(session, &Actions.dev_twink/1)
    assert {:error, :invalid, _} = result
    assert player.experience == 0
  end
end
