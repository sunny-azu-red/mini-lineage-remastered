defmodule MiniLineageWeb.PanelTest do
  @moduledoc """
  What `Controls.panel/1` renders for a fold, apart from any screen. The panels that fold in the game
  do so only on a phone, where the unit suite never looks.
  """
  use ExUnit.Case, async: true

  import Phoenix.Component, only: [sigil_H: 2]
  import Phoenix.LiveViewTest

  alias MiniLineageWeb.Controls

  defp folding(collapsed) do
    assigns = %{collapsed: collapsed}

    rendered_to_string(~H"""
    <Controls.panel id="folds" title="Folds" collapsible collapsed={@collapsed}>body</Controls.panel>
    """)
  end

  defp tag(html, selector),
    do: html |> LazyHTML.from_fragment() |> LazyHTML.query(selector) |> Enum.at(0)

  test "a collapsible header is a button that says whether it is open, and asks for the hook" do
    html = folding(false)

    assert html =~ ~s(phx-hook="Panel")
    assert LazyHTML.attribute(tag(html, "button.panel-header"), "aria-expanded") == ["true"]
    assert LazyHTML.attribute(tag(html, "button.panel-header"), "type") == ["button"]
    assert LazyHTML.attribute(tag(html, ".panel-body"), "hidden") == []
  end

  # The stylesheet hides a folded body off `aria-expanded`, so a layout with room for the panel can
  # keep it open before any script runs. A `hidden` here would shut it everywhere until one did.
  test "and one that opens collapsed says so on its header alone" do
    html = folding(true)

    assert LazyHTML.attribute(tag(html, "button.panel-header"), "aria-expanded") == ["false"]
    assert LazyHTML.attribute(tag(html, ".panel-body"), "hidden") == []
  end

  test "keeps the reader's fold unless told not to, and names its subject for the hook" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <Controls.panel id="p" title="P" collapsible remember={false} subject="abc">body</Controls.panel>
      """)

    assert LazyHTML.attribute(tag(html, "#p"), "data-remember") == ["false"]
    assert LazyHTML.attribute(tag(html, "#p"), "data-subject") == ["abc"]
    refute folding(false) =~ "data-remember"
  end

  # The hook reads which edge is the present off `data-log`, and words the pill from its data: the
  # count is the reader's, so only the nouns and the direction come from the server.
  test "a log names the order it reads in, and gives the pill its words" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <Controls.panel
        id="l"
        title="L"
        log={:newest_first}
        at_present="log_at_present"
        unread={{"new entry", "new entries"}}
      >
        body
      </Controls.panel>
      """)

    assert html =~ ~s(phx-hook="Panel")
    assert LazyHTML.attribute(tag(html, "#l"), "data-log") == ["newest-first"]
    assert LazyHTML.attribute(tag(html, "#l"), "data-at-present") == ["log_at_present"]
    pill = tag(html, "#l > button.panel-unread")
    assert LazyHTML.attribute(pill, "hidden") == [""]
    assert LazyHTML.attribute(pill, "data-one") == ["new entry"]
    assert LazyHTML.attribute(pill, "data-many") == ["new entries"]
    assert LazyHTML.attribute(pill, "data-rest") == ["more above"]
  end

  test "and a chat, read oldest first, has what it missed below" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <Controls.panel id="c" title="C" log={:oldest_first} unread={{"new message", "new messages"}}>
        body
      </Controls.panel>
      """)

    assert LazyHTML.attribute(tag(html, "#c"), "data-log") == ["oldest-first"]
    assert LazyHTML.attribute(tag(html, "#c > .panel-unread"), "data-rest") == ["more below"]
  end

  test "while a plain panel has no control and no hook at all" do
    assigns = %{}
    html = rendered_to_string(~H|<Controls.panel title="Plain">body</Controls.panel>|)

    refute html =~ "phx-hook"
    refute html =~ "<button"
  end
end
