defmodule MiniLineageWeb.CharacterPageTest do
  @moduledoc "The character's own page, which carries every stat the sidebar no longer does."
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias MiniLineage.Game.{Clock, Constants, Math, Player, Snapshot}
  alias MiniLineageWeb.Screens

  @figures ~w(str con dex int wit men p_atk m_atk p_def m_def accuracy evasion atk_spd cast_spd)a

  # Rules §3 to §10, worked for the run's own set and level: every number the base layer gives it.
  test "shows every stat the rules give the run, at its level" do
    {player, _} = Player.initialize(%Player{}, Constants.race(3), :fighter, "Sunny")
    player = %{player | experience: Math.xp_for_level(5)}
    stats = Player.stats(player)

    doc = page(player)
    read = &(doc |> LazyHTML.query(&1) |> LazyHTML.text())

    for stat <- @figures do
      key = "char-" <> String.replace(to_string(stat), "_", "-")
      assert read.(~s([data-key="#{key}"])) == Integer.to_string(Math.js_round(stats[stat])), key
    end

    assert read.("#character-critical") == "#{Float.round(stats.critical, 1)}% Critical"

    assert read.("#character-magic-critical") ==
             "#{Float.round(stats.magic_critical, 1)}% M. Critical"
  end

  # Rules §16, by day: a buff reads as one, and what it changes wears the stat it changes.
  test "the Mother Tree's blessing is a buff, and mends in the colour of mending" do
    Clock.put_now(~U[2026-07-01 09:00:00Z])
    {elf, _} = Player.initialize(%Player{}, Constants.race(2), :fighter, "Rester")
    doc = page(%{elf | location: "elven-village"})
    texts = &(doc |> LazyHTML.query(&1) |> Enum.map(fn node -> LazyHTML.text(node) end))

    assert texts.("#effect-mother_tree .buff") == ["🌳 Blessing of the Mother Tree"]
    assert texts.("#effect-mother_tree .regen") == ["×1.5 HP regen", "×1.5 MP regen"]
    assert texts.("#effect-resting .aura") == ["💤 Resting"]
  end

  defp page(player) do
    view = Snapshot.build(player)
    catalog = Snapshot.catalog()

    html =
      for panel <- Screens.panels("character", view, catalog), into: "" do
        render_component(&Screens.screen/1,
          screen: "character",
          panel: panel,
          view: view,
          catalog: catalog
        )
      end

    LazyHTML.from_fragment(html)
  end
end
