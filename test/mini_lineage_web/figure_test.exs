defmodule MiniLineageWeb.FigureTest do
  @moduledoc """
  A figure's text is where `AnimatedValues` lands and its `data-value` is where it counts to, so
  the two must say the same number in the same format, or the last frame jumps.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias MiniLineage.Game.{Constants, Format, Player, Snapshot}
  alias MiniLineageWeb.{Controls, Screens}

  defp figures(html) do
    html
    |> LazyHTML.from_fragment()
    |> LazyHTML.query("[data-value]")
    |> Enum.map(fn el ->
      {LazyHTML.attribute(el, "data-format"), LazyHTML.attribute(el, "data-value"),
       LazyHTML.text(el)}
    end)
  end

  defp said(["adena"], value), do: Format.adena(String.to_integer(value))
  defp said([], value), do: Format.number(String.to_integer(value))

  test "a figure is written from its one value, in the format it counts in" do
    assert [{[], ["12345"], "12,345"}] =
             figures(render_component(&Controls.figure/1, key: "k", value: 12_345))

    assert [{["adena"], ["2000"], "2k"}] =
             figures(render_component(&Controls.figure/1, key: "k", value: 2_000, format: :adena))
  end

  test "every figure on a record says what it counts to" do
    {player, _} = Player.initialize(%Player{}, Constants.race(1), :fighter, "Counted")
    player = %{player | adena: 12_345, experience: 4_321}

    html =
      render_component(&Screens.screen/1,
        view: Snapshot.build(player),
        screen: "character",
        catalog: Snapshot.catalog(),
        boards: %{},
        statistics: nil,
        record: %{
          id: "counted",
          name: "Counted",
          inserted_at: DateTime.utc_now(),
          last_seen_at: DateTime.utc_now(),
          active: true,
          dead: false
        },
        record_view: Snapshot.build(player),
        record_log: [],
        from: nil
      )

    found = figures(html)
    assert length(found) > 10

    for {format, [value], text} <- found do
      assert text == said(format, value), "#{inspect(format)} #{value} reads #{inspect(text)}"
    end
  end
end
