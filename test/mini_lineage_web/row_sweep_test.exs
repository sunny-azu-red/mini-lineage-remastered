defmodule MiniLineageWeb.RowSweepTest do
  @moduledoc """
  A Halls row sweeps when its `data-stamp` changes, and the stamp is the run's last chronicle entry:
  every deed writes one, a buff lapsing included, and nothing that is not a deed does.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias MiniLineage.Game.{Player, Snapshot}
  alias MiniLineageWeb.Screens.Halls

  defp row(overrides) do
    Map.merge(
      %{
        id: "abc",
        name: "Sunny",
        race_id: 0,
        level: 3,
        total_xp: 2_000,
        adena: 500,
        dead: false,
        disqualified: false,
        active: true,
        online: false,
        medal: nil,
        inserted_at: ~U[2026-09-20 10:00:00.000000Z],
        last_seen_at: ~U[2026-09-25 10:00:00.000000Z]
      },
      overrides
    )
  end

  defp stamp(row) do
    html =
      render_component(&Halls.screen/1,
        view: Snapshot.build(%Player{}),
        catalog: Snapshot.catalog(),
        boards: %{nil => [row]}
      )

    [_, stamp] = Regex.run(~r/data-stamp="([^"]*)"/, html)
    stamp
  end

  test "moves when the chronicle gains an entry that moves no figure, as a buff lapsing does" do
    before = row(%{})
    lapsed = row(%{last_seen_at: ~U[2026-09-25 10:05:00.000000Z]})

    refute stamp(lapsed) == stamp(before)
  end

  test "and holds while nothing is logged" do
    assert stamp(row(%{online: true})) == stamp(row(%{}))
  end
end
