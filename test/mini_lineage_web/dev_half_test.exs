defmodule MiniLineageWeb.DevHalfTest do
  @moduledoc """
  Typing `half` in a debug build sets HP and MP to half their maximum and the XP bar halfway to the
  next level, so every bar can be seen part full. Not async: a release is a flip of the debug build.
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
    |> render_submit(%{"name" => "Halver", "race_id" => "1", "path" => "fighter"})

    {view, session}
  end

  defp type(view, letters) do
    for <<letter <- letters>>, do: render_hook(view, "key", %{"key" => <<letter>>})
    render(view)
  end

  # Read back from the table: a regeneration tick only buffers, so it cannot move what was written.
  test "typing it halves both bars and puts the XP bar halfway", %{conn: conn} do
    {view, session} = started(conn)

    assert type(view, "half") =~ "halves your HP and MP"
    player = stored(session)
    stats = Player.stats(player)

    assert player.health == trunc(stats.max_hp / 2)
    assert player.mp == trunc(stats.max_mp / 2)
    assert player.experience == div(Math.xp_for_level(2), 2)
    assert Player.level(player) == 1
  end

  test "at the last level the XP is left alone, having no next level" do
    top = Math.xp_for_level(Rules.max_level()) + 5

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

    assert {%{experience: ^top}, {:ok, _}} = Actions.dev_half(player)
  end

  test "a release never listens for it, nor answers it" do
    previous = Application.fetch_env!(:mini_lineage, :debug_build)
    Application.put_env(:mini_lineage, :debug_build, false)
    on_exit(fn -> Application.put_env(:mini_lineage, :debug_build, previous) end)

    {view, session} = started(build_conn())
    before = stored(session)

    type(view, "half")
    assert stored(session).experience == before.experience

    {result, player} = Characters.mutate(session, &Actions.dev_half/1)
    assert {:error, :invalid, _} = result
    assert player.experience == 0
  end
end
