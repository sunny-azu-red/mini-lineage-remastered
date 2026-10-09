defmodule MiniLineageWeb.DevLevelTest do
  @moduledoc """
  Typing `lvl` in a debug build hands over exactly the EXP the next level needs, and `maxlvl` the
  EXP the last one needs; reaching a level refills both bars as rules §12 says. Not async: a release
  is a flip of the debug build.
  """
  use MiniLineageWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import MiniLineage.DataCase, only: [stored: 1]

  alias MiniLineage.Characters
  alias MiniLineage.Game.{Actions, Math, Player, Rules}

  defp started(conn) do
    session = Characters.new_session_id()
    on_exit(fn -> Characters.forget(session) end)
    {:ok, view, _html} = conn |> init_test_session(%{"session_id" => session}) |> live(~p"/")

    view
    |> element("form[phx-submit=start]")
    |> render_submit(%{"name" => "Climber", "race_id" => "1", "path" => "fighter"})

    {view, session}
  end

  defp type(view, letters) do
    for <<letter <- letters>>, do: render_hook(view, "key", %{"key" => <<letter>>})
    render(view)
  end

  test "typing it reaches the next level exactly, with both bars full", %{conn: conn} do
    {view, session} = started(conn)

    type(view, "half")
    assert type(view, "lvl") =~ "enough to reach"
    player = stored(session)
    stats = Player.stats(player)

    assert player.experience == Math.xp_for_level(2)
    assert {player.health, player.mp} == {stats.max_hp, stats.max_mp}

    type(view, "lvl")
    assert stored(session).experience == Math.xp_for_level(3)
  end

  test "typing maxlvl reaches the last level, and the lvl it ends in does not answer", %{
    conn: conn
  } do
    {view, session} = started(conn)

    type(view, "half")
    assert type(view, "maxlvl") =~ "Level #{Rules.max_level()}"
    player = stored(session)
    stats = Player.stats(player)

    assert player.experience == Math.xp_for_level(Rules.max_level())
    assert {player.health, player.mp} == {stats.max_hp, stats.max_mp}

    assert type(view, "maxlvl") =~ "There is no level past the last."
    assert stored(session).experience == Math.xp_for_level(Rules.max_level())
  end

  test "EXP that reaches no new level leaves the bars alone" do
    player = %Player{race_id: 1, path: :fighter, health: 1, mp: 1, experience: 0}

    assert %{health: 1, mp: 1, experience: 67} = Player.gain_experience(player, 67)
    assert %{experience: 68, health: hp} = Player.gain_experience(player, 68)
    assert hp > 1
  end

  test "at the last level it refuses, having no next one" do
    top = Math.xp_for_level(Rules.max_level())

    player = %Player{
      name: "Elder",
      race_id: 1,
      path: :fighter,
      health: 1,
      mp: 1,
      adena: 0,
      experience: top,
      location: "talking-island"
    }

    assert {%{experience: ^top}, {:error, :last_level, _}} = Actions.dev_level(player)
    assert {%{experience: ^top}, {:error, :last_level, _}} = Actions.dev_max_level(player)
  end

  test "a release never listens for it, nor answers it" do
    previous = Application.fetch_env!(:mini_lineage, :debug_build)
    Application.put_env(:mini_lineage, :debug_build, false)
    on_exit(fn -> Application.put_env(:mini_lineage, :debug_build, previous) end)

    {view, session} = started(build_conn())

    type(view, "lvl")
    type(view, "maxlvl")
    assert stored(session).experience == 0

    for action <- [&Actions.dev_level/1, &Actions.dev_max_level/1] do
      {result, player} = Characters.mutate(session, action)
      assert {:error, :invalid, _} = result
      assert player.experience == 0
    end
  end
end
