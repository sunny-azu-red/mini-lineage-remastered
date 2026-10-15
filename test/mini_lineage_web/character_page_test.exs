defmodule MiniLineageWeb.CharacterPageTest do
  @moduledoc "The character's own page, which carries every stat the sidebar no longer does."
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias MiniLineage.Game.{Clock, Constants, Math, Player, Snapshot}
  alias MiniLineageWeb.Screens

  @figures ~w(str con dex int wit men p_atk m_atk p_def m_def accuracy evasion atk_spd cast_spd run_spd hp_regen mp_regen)a

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

  # What the character deals, then what it withstands and running (§20); Accuracy follows the blow it
  # aims. Resting happens out of a fight, so it reads with the bars it fills.
  test "combat stats read what is dealt, then what is withstood, and resting sits with HP and MP" do
    {player, _} = Player.initialize(%Player{}, Constants.race(3), :fighter, "Sunny")
    doc = page(player)

    keys = fn selector ->
      doc |> LazyHTML.query(selector) |> LazyHTML.attribute("data-key")
    end

    assert keys.("#character-stats p:nth-of-type(1) [data-key]") ==
             ~w(char-p-atk char-atk-spd char-critical char-accuracy char-m-atk char-cast-spd char-magic-critical)

    assert keys.("#character-stats p:nth-of-type(2) [data-key]") ==
             ~w(char-p-def char-evasion char-m-def char-run-spd)

    assert doc |> LazyHTML.query("#character-stats p") |> Enum.count() == 2

    assert LazyHTML.query(doc, "#character-stats p:nth-of-type(1) #character-critical")
           |> Enum.count() == 1

    assert LazyHTML.query(doc, "#character-stats p:nth-of-type(1) #character-magic-critical")
           |> Enum.count() == 1

    assert keys.("#character-vitality .regen [data-key]") == ~w(char-hp-regen char-mp-regen)
    assert keys.("#character-stats .regen") == []
  end

  # Rules §23, its example: a worn shield catches blows at its block rate × the DEX bonus, so it
  # reads with them, between P.Def and Evasion, and not at all without one.
  test "a shield's block reads with the blows it catches, only while one is worn" do
    {player, _} = Player.initialize(%Player{}, Constants.race(0), :fighter, "Sunny")

    keys = fn doc ->
      doc
      |> LazyHTML.query("#character-stats p:nth-of-type(2) [data-key]")
      |> LazyHTML.attribute("data-key")
    end

    refute "char-block" in keys.(page(player))

    doc = page(%{player | items: player.items ++ [Player.new_item("Small Shield", true)]})

    assert keys.(doc) ==
             ~w(char-p-def char-block char-evasion char-m-def char-run-spd)

    assert doc |> LazyHTML.query("#character-block") |> LazyHTML.text() == "22.0% Block"
  end

  # Rules §11: what a tick of rest mends, or costs, is said on the row as the tooltip says it, in
  # figures, since it moves with the level and as each bar fills.
  test "Regenerating and Relax say what a tick of rest mends and costs" do
    Clock.put_now(~U[2026-07-01 12:00:00Z])
    {orc, _} = Player.initialize(%Player{}, Constants.race(1), :fighter, "Rester")
    orc = %{orc | location: "gludio", health: 1, mp: 10, skills: Map.put(orc.skills, "Relax", 1)}
    stats = Player.stats(orc)
    doc = page(orc)
    text = &(doc |> LazyHTML.query(&1) |> LazyHTML.text() |> String.replace(~r/\s+/, " "))
    keys = &(doc |> LazyHTML.query(&1) |> LazyHTML.attribute("data-key"))
    {hp, mp} = {Math.js_round(stats.hp_regen), Math.js_round(stats.mp_regen)}

    assert text.("#effect-regenerating") =~ "+#{hp} HP and +#{mp} MP every three seconds."

    assert keys.("#effect-regenerating [data-key]") ==
             ~w(effect-regenerating-hp effect-regenerating-mp)

    assert LazyHTML.attribute(LazyHTML.query(doc, "#effect-regenerating"), "phx-hook") == [
             "AnimatedValues"
           ]

    assert text.("#effect-relax") =~ "+5 HP and -3 MP every three seconds."
  end

  # Rules §16, by day: a buff reads as one, and what it changes wears the stat it changes.
  test "the Mother Tree's blessing is a buff, and mends in the colour of mending" do
    Clock.put_now(~U[2026-07-01 09:00:00Z])
    {elf, _} = Player.initialize(%Player{}, Constants.race(2), :fighter, "Rester")
    doc = page(%{elf | location: "elven-village"})
    texts = &(doc |> LazyHTML.query(&1) |> Enum.map(fn node -> LazyHTML.text(node) end))

    assert texts.("#effect-mother_tree .buff") == ["🌳 Blessing of the Mother Tree"]
    assert texts.("#effect-mother_tree .regen") == ["+50% HP regen", "+50% MP regen"]
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
