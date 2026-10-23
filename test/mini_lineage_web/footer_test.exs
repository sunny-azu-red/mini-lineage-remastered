defmodule MiniLineageWeb.FooterTest do
  @moduledoc """
  The footer's year and the banner's clock are the game's, kept in its zone (rules §15), here
  Bucharest's, put on the game for this module. Not async: the zone is the node's.
  """
  use ExUnit.Case, async: false

  import Phoenix.LiveViewTest

  alias MiniLineage.Game.Clock
  alias MiniLineageWeb.Layouts

  setup do: MiniLineage.Zone.put("Europe/Bucharest")

  # Half past midnight on New Year's Day in Bucharest, 22:30 on New Year's Eve in UTC.
  @new_year ~U[2026-12-31 22:30:00Z]

  test "a new year begins at the game's midnight, while UTC is still in the old one" do
    Clock.put_now(@new_year)

    assert render_component(&Layouts.footer/1, %{}) =~ "2005 &ndash; 2027"
  end

  test "the banner keeps the game's clock, naming its zone, with no emoji of its own" do
    Clock.put_now(@new_year)

    assert render_component(&Layouts.site_header/1, %{}) =~
             ~s(<span id="game-clock" title="The game's clock, which night and every date keep">12:30 am EET</span>)
  end
end
