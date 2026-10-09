defmodule MiniLineageWeb.StatusPanelTest do
  @moduledoc """
  The sidebar the town carries. Its figures animate, so each is its own element, and HEEx renders
  a newline between elements as a space, which this reads through.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias MiniLineage.Game.{Constants, Math, Player, Snapshot}

  @figures ~w(str con dex int wit men p_atk m_atk p_def m_def accuracy evasion atk_spd cast_spd)a

  defp sidebar_for(player) do
    render_component(&MiniLineageWeb.Layouts.app/1,
      title: "Dark Elven Village",
      view: Snapshot.build(player),
      screen: "town",
      inner_block: [%{inner_block: fn _, _ -> "" end, __slot__: :inner_block}]
    )
  end

  defp text(html), do: html |> String.replace(~r/<[^>]+>/, "") |> String.replace(~r/\s+/, " ")

  setup do
    {player, _} = Player.initialize(%Player{}, Constants.race(3), :fighter, "Sunny")

    %{html: sidebar_for(%{player | experience: Math.xp_for_level(5)})}
  end

  test "reads the race line as one line, whatever the markup underneath it", %{html: html} do
    assert text(html) =~ "Race 🧛 Dark Fighter 5"
  end

  test "and leaves no space in front of any punctuation", %{html: html} do
    assert Regex.scan(~r/\S+ [,.]/, text(html)) == [], text(html)
  end

  test "every figure it shows is one the hook can count", %{html: html} do
    keys = Regex.scan(~r/data-key="([^"]+)"/, html) |> Enum.map(&List.last/1)

    stats = Enum.map(@figures, &String.replace(to_string(&1), "_", "-"))

    assert Enum.sort(keys) ==
             Enum.sort(~w(adena hp level max-hp max-mp mp xp xp-required) ++ stats)
  end

  test "a new character's purse holds nothing", %{html: _html} do
    {player, _} = Player.initialize(%Player{}, Constants.race(0), :mystic, "Sunny")

    assert sidebar_for(player) =~ ~r|data-key="adena"[^>]*>0</span>|
  end

  # Rules §3 to §10, worked for the run's own set and level: every number the base layer gives it.
  test "the Stats panel shows every stat the rules give the run, at its level", %{html: html} do
    {player, _} = Player.initialize(%Player{}, Constants.race(3), :fighter, "Sunny")
    stats = Player.stats(%{player | experience: Math.xp_for_level(5)})
    doc = LazyHTML.from_fragment(html)
    read = &(doc |> LazyHTML.query("#stats " <> &1) |> LazyHTML.text())

    for stat <- @figures do
      key = String.replace(to_string(stat), "_", "-")
      assert read.(~s([data-key="#{key}"])) == Integer.to_string(Math.js_round(stats[stat])), key
    end

    assert read.("#stat-critical") == "#{Float.round(stats.critical, 1)}%"
    assert read.("#stat-magic-critical") == "#{Float.round(stats.magic_critical, 1)}%"
  end

  # Beside the main panel the others stay open; Stats folds at every width, and starts folded.
  test "the Stats panel opens folded, and folds wherever it stands", %{html: html} do
    doc = LazyHTML.from_fragment(html)

    assert doc |> LazyHTML.query("#stats") |> LazyHTML.attribute("class") == ["panel folds"]

    assert doc |> LazyHTML.query("#stats > .panel-toggle") |> LazyHTML.attribute("aria-expanded") ==
             ["false"]
  end
end
