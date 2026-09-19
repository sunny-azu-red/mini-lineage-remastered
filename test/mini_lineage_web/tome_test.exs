defmodule MiniLineageWeb.TomeTest do
  @moduledoc """
  The Tome of Lore, which is the one screen whose figures belong to everybody.

  It is also the screen where a count earns its keep most: the collector flushes on a timer, so
  with a realm full of players the archives arrive having moved a long way at once.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias MiniLineage.Game.{Player, Snapshot, Statistics}

  defp render_tome(stats) do
    render_component(&MiniLineageWeb.Screens.Tome.screen/1,
      view: Snapshot.build(%Player{}),
      statistics: stats
    )
  end

  defp filled(over) do
    Statistics.fields() |> Map.new(&{&1, 4_321}) |> Map.merge(over)
  end

  test "every counter it tells is one the hook can count" do
    html = render_tome(filled(%{total_players: 7}))

    keys = Regex.scan(~r/data-key="([^"]+)"/, html) |> Enum.map(&List.last/1)
    told = Regex.scan(~r/@statistics\.(\w+)/, File.read!("lib/mini_lineage_web/screens/tome.ex"))

    # Against what the screen TELLS, not against every counter kept: `total_adena` is collected and
    # has never been part of the story, so counting fields would only ever assert that.
    assert length(keys) == length(Enum.uniq(told)),
           "#{length(keys)} wired of #{length(Enum.uniq(told))} told"
  end

  test "and one hook covers them all" do
    assert render_tome(filled(%{total_players: 7})) =~ ~s|id="tome-figures"|
  end

  test "a count of one is a word, and has no figure to tween" do
    html = render_tome(filled(%{total_players: 1, total_deaths: 1}))

    text = html |> String.replace(~r/<[^>]+>/, "") |> String.replace(~r/\s+/, " ")

    assert text =~ "a Brave Soul"
    refute text =~ "1 Brave Souls"
  end

  test "and the prose never leaves a space in front of its punctuation" do
    for stats <- [filled(%{total_players: 7}), filled(%{total_players: 1, total_deaths: 1})] do
      text =
        stats |> render_tome() |> String.replace(~r/<[^>]+>/, "") |> String.replace(~r/\s+/, " ")

      assert Regex.scan(~r/\S+ [,.]/, text) == [], text
    end
  end
end
