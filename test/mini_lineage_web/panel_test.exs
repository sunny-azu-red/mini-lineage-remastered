defmodule MiniLineageWeb.PanelTest do
  @moduledoc """
  What `Controls.panel/1` renders for a fold, apart from any screen. Folding happens in the browser,
  where the walkthrough looks.
  """
  use ExUnit.Case, async: true

  import Phoenix.Component, only: [sigil_H: 2]
  import Phoenix.LiveViewTest

  alias MiniLineageWeb.Controls

  defp folding do
    assigns = %{}

    rendered_to_string(~H"""
    <Controls.panel id="folds" title="Folds" collapsible>body</Controls.panel>
    """)
  end

  defp tag(html, selector),
    do: html |> LazyHTML.from_fragment() |> LazyHTML.query(selector) |> Enum.at(0)

  # Drawn folded, for the hook to open: a panel popping open reads better than one snapping shut.
  # The stylesheet hides a folded body off `aria-expanded` alone, so a `hidden` would be a second
  # state for the hook to keep in step.
  test "a collapsible header is a button drawn folded, which the hook opens and patches leave alone" do
    html = folding()
    header = tag(html, "button.panel-header")

    assert html =~ ~s(phx-hook="Panel")
    assert LazyHTML.attribute(header, "aria-expanded") == ["false"]
    assert LazyHTML.attribute(header, "type") == ["button"]
    assert [mounted] = LazyHTML.attribute(header, "phx-mounted")
    assert mounted =~ "ignore_attrs" and mounted =~ "aria-expanded"
    assert LazyHTML.attribute(tag(html, ".panel-body"), "hidden") == []
  end

  # A button's contents are never read as a heading, so the title's h2 holds the button instead.
  test "and its title is an h2 wrapping that button, never one inside it" do
    html = folding()

    assert tag(html, ".panel > h2.panel-heading > button.panel-header > .header-name")
    refute tag(html, "button h2")
  end

  test "while a plain panel has no control and no hook at all" do
    assigns = %{}
    html = rendered_to_string(~H|<Controls.panel title="Plain">body</Controls.panel>|)

    refute html =~ "phx-hook"
    refute html =~ "<button"
    assert LazyHTML.text(tag(html, ".panel-header > h2.header-name")) == "Plain"
  end
end
