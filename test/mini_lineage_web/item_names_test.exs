defmodule MiniLineageWeb.ItemNamesTest do
  @moduledoc """
  An item is named as an item wherever it is written as text, so one rule recolours every blade,
  tunic and meal in the game at once. The shop's dropdown is the deliberate exception: an
  `<option>` holds no markup, and a form control should look like one.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias MiniLineage.Game.{Constants, Player, Snapshot}
  alias MiniLineageWeb.Screens

  defp hero do
    {player, _} = Player.initialize(%Player{}, Constants.race(1), "Hero")
    player
  end

  defp shop(screen, gear \\ []) do
    render_component(&Screens.screen/1,
      view: Snapshot.build(struct(hero(), [current_screen: screen] ++ gear)),
      screen: screen,
      catalog: Snapshot.catalog(),
      flash: %{}
    )
  end

  defp own_tag(row), do: row |> String.split(">", parts: 2) |> hd()

  defp rows(html) do
    [_, body] = Regex.run(~r|<tbody>(.*)</tbody>|s, html)
    body |> String.split("<tr") |> Enum.drop(1)
  end

  test "in every shop's table, emoji outside and the name inside" do
    for screen <- ~w(weapons armors inn) do
      names = Regex.scan(~r|<td class="name">(.*?)</td>|s, shop(screen), capture: :all_but_first)

      assert names != [], "#{screen} lists nothing"

      for [name] <- names,
          do: assert(name =~ ~r|^\S+ <span class="item">[^<]+</span>$|, "#{screen}: #{name}")
    end
  end

  # A class list prints `class=""` on every row it does not match; only the owned row has one.
  test "and a row you do not own carries no class at all" do
    rows = rows(shop("weapons", weapon_id: 2))
    {owned, others} = Enum.split_with(rows, &(own_tag(&1) =~ "class"))

    assert [row] = owned
    assert own_tag(row) =~ ~s(class="owned")
    assert length(others) == length(rows) - 1
  end

  test "and in the Inventory panel" do
    html =
      render_component(&MiniLineageWeb.Layouts.app/1,
        flash: %{},
        title: "Home Town",
        view: Snapshot.build(hero()),
        screen: "home",
        character_id: "abc",
        inner_block: [%{inner_block: fn _, _ -> "" end, __slot__: :inner_block}]
      )

    assert html =~ ~s(<span class="item">Peasant&#39;s Tunic</span>)
    assert html =~ ~s(<span class="item">Brawler&#39;s Fists</span>)
  end
end
