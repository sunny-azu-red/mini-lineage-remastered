defmodule MiniLineageWeb.BarTest do
  @moduledoc """
  A bar is a figure against its cap. Its width, its figures and what a screen reader is told come
  from the same two numbers, and without a cap it is only the figure, in a track filled to the end.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias MiniLineage.Game.{Constants, Format, Math, Player, Snapshot}
  alias MiniLineageWeb.Controls

  defp bar(opts) do
    html = render_component(&Controls.bar/1, [id: "b", label: "HP", key: "hp", kind: :hp] ++ opts)
    doc = LazyHTML.from_fragment(html)
    one = &(doc |> LazyHTML.query(&1) |> LazyHTML.attribute(&2) |> List.first())

    %{
      width: one.(".bar", "style"),
      track: fn attr -> one.(".bar-track", attr) end,
      keys: doc |> LazyHTML.query("[data-value]") |> LazyHTML.attribute("data-key"),
      formats: doc |> LazyHTML.query("[data-value]") |> LazyHTML.attribute("data-format"),
      text: doc |> LazyHTML.query(".bar-text") |> LazyHTML.text()
    }
  end

  test "fills to its share of the cap, and says so to a screen reader" do
    b = bar(value: 287, of: 1_305, of_key: "max-hp")

    assert b.width == "width:#{Math.percentage(287, 1_305, 1)}%"
    assert b.keys == ["hp", "max-hp"]
    assert b.text == "287\u00A0/\u00A01,305"
    assert b.track.("role") == "meter"
    assert b.track.("aria-valuenow") == "287"
    assert b.track.("aria-valuemax") == "1305"
    assert b.track.("aria-valuetext") == "287 of 1,305 HP"
  end

  test "reads empty at nothing and full at the cap" do
    assert bar(value: 0, of: 170, of_key: "max-hp").width == "width:0.0%"
    assert bar(value: 170, of: 170, of_key: "max-hp").width == "width:100.0%"
  end

  test "without a cap is the figure alone, in a full track" do
    b = bar(kind: :xp, label: "XP", key: "xp", value: 1_234_567)

    assert b.width == "width:100%"
    assert b.keys == ["xp"]
    assert b.text == "1,234,567"
    assert b.track.("role") == "progressbar"
    assert b.track.("aria-valuetext") == "1,234,567 XP"
  end

  # A level's EXP runs to 4.2 billion, which written out does not fit the sidebar's bar.
  test "counts in the short form when asked, and still speaks in full" do
    b =
      bar(
        kind: :xp,
        label: "XP",
        key: "xp",
        value: 1_151_275_834,
        of: 2_099_275_834,
        of_key: "xp-required",
        format: :short
      )

    assert b.text == "1.1kkk\u00A0/\u00A02kkk"
    assert b.formats == ["short", "short"]
    assert b.track.("aria-valuetext") == "1,151,275,834 of 2,099,275,834 XP"
  end

  # The XP bar reads as a share of the level, to the hundredth, and never full until it is.
  test "writes one figure as a percentage of the cap when asked, and still speaks in full" do
    b =
      bar(
        kind: :xp,
        label: "XP",
        key: "xp",
        value: 2_999,
        of: 3_000,
        of_key: "xp-required",
        format: :percent
      )

    assert b.text == "99.96%"
    assert b.keys == ["xp-percent"]
    assert b.formats == ["percent"]
    assert b.track.("aria-valuetext") == "2,999 of 3,000 XP"
  end

  test "names itself inside the track, hidden from a screen reader the track already told" do
    html = render_component(&Controls.bar/1, id: "b", label: "HP", key: "hp", kind: :hp, value: 1)
    label = html |> LazyHTML.from_fragment() |> LazyHTML.query(".bar-track > .bar-label")

    assert LazyHTML.text(label) == "HP"
    assert LazyHTML.attribute(label, "aria-hidden") == ["true"]
  end

  test "leaves its class to the hook once mounted, so a patch cannot cut a shimmer short" do
    html = render_component(&Controls.bar/1, id: "b", label: "HP", key: "hp", kind: :hp, value: 1)

    assert html =~
             ~s(phx-mounted="[[&quot;ignore_attrs&quot;,{&quot;attrs&quot;:[&quot;class&quot;]}]]")
  end

  test "the sidebar's XP bar loses its cap at the last level" do
    {player, _} = Player.initialize(%Player{}, Constants.race(1), :fighter, "Capped")
    view = Snapshot.build(%{player | experience: Math.xp_for_level(80)})

    html =
      render_component(&MiniLineageWeb.Layouts.app/1,
        title: "Orc Village",
        view: view,
        screen: "town",
        inner_block: [%{inner_block: fn _, _ -> "" end, __slot__: :inner_block}]
      )

    xp = html |> LazyHTML.from_fragment() |> LazyHTML.query("#xp-bar ~ .bar-text")

    assert LazyHTML.text(xp) == Format.short(view.experience)
    assert html =~ ~s(style="width:100%")
  end
end
