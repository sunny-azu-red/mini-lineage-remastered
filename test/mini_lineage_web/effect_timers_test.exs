defmodule MiniLineageWeb.EffectTimersTest do
  @moduledoc """
  Rules §19 and §20 on the character page: an aura raised says how long it holds, and leaving the
  ground how long until rest. The server sends a duration, which `EffectTimers` counts down.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias MiniLineage.Game.{Clock, Constants, Player, Snapshot}
  alias MiniLineageWeb.Screens

  @noon ~U[2026-07-01 12:00:00Z]

  setup do
    Clock.put_now(@noon)
    :ok
  end

  # Away from Elven Village, so the Mother Tree adds nothing, and by day, so night adds nothing.
  defp elf do
    {elf, _} = Player.initialize(%Player{}, Constants.race(2), :fighter, "Sunny")
    %{elf | location: "town-of-gludio", skills: Map.put(elf.skills, "Defense Aura", 1)}
  end

  test "a raised aura says what it adds as a percentage, and counts down its two minutes" do
    raised = Player.put_buffs(elf(), ["Defense Aura"])
    Clock.put_now(DateTime.add(@noon, 23))
    doc = page(raised)

    assert text(doc, "#effect-defense_aura") =~
             "An aura raised in the field turns blows aside. +8% P. Def. for another 1m 37s."

    assert attribute(doc, "#effect-defense_aura .timer", "data-remaining-ms") == "97000"
    assert attribute(doc, "#effect-defense_aura", "phx-hook") == "EffectTimers"
  end

  test "leaving the ground counts down to rest, and the ground itself has no end to count to" do
    engaged = %{elf() | combat: "engaged"}
    doc = page(engaged)

    assert text(doc, "#effect-combat") =~ "In Combat"
    assert LazyHTML.query(doc, "#effect-combat .timer") |> Enum.count() == 0
    assert attribute(doc, "#effect-combat", "phx-hook") == nil

    leaving = Player.disengage(engaged)
    Clock.put_now(DateTime.add(@noon, 2))

    assert text(page(leaving), "#effect-combat") =~ "You rest again in 3s."
  end

  test "an effect that never ends says nothing of time" do
    doc = page(elf())

    assert text(doc, "#effect-resting") =~ "Resting"
    assert LazyHTML.query(doc, ".timer") |> Enum.count() == 0
  end

  defp text(doc, selector), do: doc |> LazyHTML.query(selector) |> LazyHTML.text()

  defp attribute(doc, selector, name) do
    case doc |> LazyHTML.query(selector) |> LazyHTML.attribute(name) do
      [value] -> value
      [] -> nil
    end
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
