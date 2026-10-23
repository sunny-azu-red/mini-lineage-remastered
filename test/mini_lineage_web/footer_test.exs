defmodule MiniLineageWeb.FooterTest do
  @moduledoc "The footer's year and clock are the game's, kept in its zone (rules §15)."
  use ExUnit.Case, async: false

  import Phoenix.LiveViewTest

  alias MiniLineage.Game.Clock
  alias MiniLineageWeb.Layouts

  test "a new year begins at the game's midnight, while UTC is still in the old one" do
    # Half past midnight on New Year's Day in Bucharest, 22:30 on New Year's Eve in UTC.
    Clock.put_now(~U[2026-12-31 22:30:00Z])

    html = render_component(&Layouts.footer/1, %{})
    assert html =~ "2005 &ndash; 2027"
    assert html =~ "🕰️ 12:30 am EET"
  end
end
