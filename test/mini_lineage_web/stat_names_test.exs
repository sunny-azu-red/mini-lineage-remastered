defmodule MiniLineageWeb.StatNamesTest do
  @moduledoc """
  One way to write a stat, a bonus, a rate and a mend, on every page that names them, for every set
  knowing every lesson its trainer teaches: the client's spelling, a bonus before its stat, an
  item's own number after it, a rate with its %, and HP mended, never healed.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias MiniLineage.Game.{Clock, Constants, Player, Rules, Snapshot}
  alias MiniLineageWeb.Screens

  setup do
    Clock.put_now(~U[2026-07-01 12:00:00Z])
    :ok
  end

  test "every page writes a stat, a bonus, a rate and a mend one way" do
    # Every item's line too, since a trader shows what the character does not carry.
    lines =
      Enum.map_join(
        Map.values(Rules.items()) ++ Map.values(Rules.potions()),
        ". ",
        &Snapshot.about/1
      )

    for set <- Rules.sets(), screen <- ~w(character guild inventory) do
      text = unnamed(page(knowing_all(set), screen) <> " " <> lines)

      refute text =~ ~r/\b[PM]\.(Atk|Def)\b/, "#{set.name} #{screen}: #{text}"
      refute text =~ ~r/Cast\. Spd|Run Spd/, "#{set.name} #{screen}: #{text}"
      refute text =~ ~r/\.\./, "#{set.name} #{screen}: #{text}"
      refute text =~ ~r/\b(Accuracy|Evasion|MP) [+-]\d/, "#{set.name} #{screen}: #{text}"
      refute text =~ ~r/(Critical|Block) \d+(?![\d.%])/, "#{set.name} #{screen}: #{text}"
      refute text =~ ~r/\bheal/i, "#{set.name} #{screen}: #{text}"
    end
  end

  test "an item writes its own numbers after their stat and a bonus before it" do
    assert Snapshot.about(Rules.item("Squire's Bow")) ==
             "P. Atk. 14, M. Atk. 5, Atk. Spd. 293, Critical 12%, Damage ±5%, -3 Accuracy"

    assert Snapshot.about(Rules.item("Buckler")) =~ "Block 20%, -8 Evasion"
    assert Snapshot.about(Rules.item("Cotton Tunic")) =~ ", +38 MP"
    assert Snapshot.about(Rules.item("Lesser Healing Potion")) == "Mends 112 HP at once"
  end

  # The set knowing every line its trainer teaches, at level 1.
  defp knowing_all(set) do
    {player, _} = Player.initialize(%Player{}, Constants.race(set.race_id), set.path, "Sunny")
    skills = for l <- Rules.lessons(set.name), into: %{}, do: {l.skill, 1}
    %{player | skills: skills, location: Rules.hometown(set.race_id)}
  end

  # Skill and item names are spelt as they are, "Self Heal" and "Healing Potion" included.
  defp unnamed(text) do
    names =
      Enum.flat_map(Rules.sets(), &Enum.map(Rules.lessons(&1.name), fn l -> l.skill end)) ++
        Map.keys(Rules.items()) ++ Map.keys(Rules.potions())

    names
    |> Enum.uniq()
    |> Enum.sort_by(&(-String.length(&1)))
    |> Enum.reduce(text, &String.replace(&2, &1, ""))
  end

  defp page(player, screen) do
    view = Snapshot.build(player)
    catalog = Snapshot.catalog()

    for panel <- Screens.panels(screen, view, catalog), into: "" do
      render_component(&Screens.screen/1,
        screen: screen,
        panel: panel,
        view: view,
        catalog: catalog
      )
    end
    |> LazyHTML.from_fragment()
    |> LazyHTML.text()
    |> String.replace(~r/\s+/, " ")
  end
end
