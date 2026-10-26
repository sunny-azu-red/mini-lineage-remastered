defmodule MiniLineageWeb.NamesTest do
  @moduledoc """
  One way to name an item or a skill, on every page and in every flash that names one: in `.item`
  or `.skill`, led by its emoji, as `Names` writes it. Only an `<option>`, which holds no markup,
  names one as text, and a stat ("Shield P. Def."), a slot ("Shield") or a setting ("Drink Healing
  Potion") is no name.
  """
  use ExUnit.Case, async: true

  import Phoenix.Component, only: [sigil_H: 2]
  import Phoenix.LiveViewTest

  alias MiniLineage.Game.{Actions, Clock, Constants, Names, Player, Rules, Snapshot}
  alias MiniLineageWeb.{Controls, Layouts, Screens}

  setup do
    Clock.put_now(~U[2026-07-01 12:00:00Z])
    :ok
  end

  @screens ~w(character guild inventory trader-weapon trader-armour trader-magic trader-sell hunt)

  defp item_names, do: Map.keys(Rules.items()) ++ Map.keys(Rules.potions())

  defp skill_names,
    do:
      Enum.uniq(
        Enum.flat_map(Rules.sets(), fn s -> Enum.map(Rules.lessons(s.name), & &1.skill) end)
      )

  # What is left of a page once every name written the one way is taken out: any name still in it
  # was written another way.
  defp bare(html) do
    html =
      html
      |> String.replace(~r/<option[^>]*>.*?<\/option>/s, "")
      |> String.replace(~r/<td>(Weapon|Shield|Chest|Legs|Necklace|Potion)<\/td>/, "")
      |> then(
        &Enum.reduce(item_names(), &1, fn name, html ->
          String.replace(html, Names.item(name), "")
        end)
      )
      |> then(
        &Enum.reduce(skill_names(), &1, fn name, html ->
          String.replace(
            html,
            ~r/#{Regex.escape(String.replace(Names.skill(name), "</span>", ""))}( \d+)?<\/span>/,
            ""
          )
        end)
      )
      |> String.replace(~r/<[^>]+>/, " ")
      |> String.replace(~r/Shield P\. Def\.|Drink Healing Potion/, "")

    for name <- Enum.sort_by(item_names() ++ skill_names(), &(-String.length(&1))),
        html =~ ~r/\b#{Regex.escape(name)}\b/,
        do: name
  end

  defp player(set, twinked?) do
    {player, _} = Player.initialize(%Player{}, Constants.race(set.race_id), set.path, "Sunny")
    player = %{player | location: Rules.hometown(set.race_id)}
    player = if twinked?, do: elem(Actions.dev_twink(player), 0), else: player
    skills = for l <- Rules.lessons(set.name), into: player.skills, do: {l.skill, l.level}
    %{player | skills: skills}
  end

  # The whole page, the sidebar and every panel, as `GameLive` draws it.
  defp page(player, screen) do
    view = Snapshot.build(player)
    catalog = Snapshot.catalog()

    assigns = %{
      panels: Screens.panels(screen, view, catalog),
      view: view,
      screen: screen,
      catalog: catalog
    }

    rendered_to_string(~H"""
    <Layouts.app :let={panel} panels={@panels} view={@view} screen={@screen}>
      <Screens.screen screen={@screen} panel={panel} view={@view} catalog={@catalog} />
    </Layouts.app>
    """)
  end

  test "every page names an item or a skill the one way" do
    for set <- Rules.sets(), twinked? <- [false, true], screen <- @screens do
      html = page(player(set, twinked?), screen)
      assert bare(html) == [], "#{set.name} #{screen}: #{inspect(bare(html))}"
    end
  end

  test "every flash names an item or a skill the one way" do
    for set <- Rules.sets() do
      # A spare to equip, destroy and sell beside what it wears, whatever its kit holds.
      spare = Player.new_item("Long Sword", false, 1)
      geared = player(set, true)
      start = %{geared | items: geared.items ++ [spare]}
      potion = Enum.find(start.items, &Rules.stacks?(Rules.item(&1.name)))
      worn = Enum.find(start.items, & &1.equipped)

      flashes =
        [
          Actions.buy(%{start | items: []}, potion.name, 2),
          Actions.buy(%{start | adena: 0, items: []}, potion.name, 2),
          Actions.drink(%{start | health: 1}, potion.id),
          Actions.unequip(start, worn.id),
          Actions.equip(start, spare.id),
          Actions.destroy(start, spare.id),
          Actions.sell(start, spare.id)
        ]
        |> Enum.map(fn
          {_player, {:ok, flash}} -> flash.text
          {_player, {:error, _code, text}} -> text
        end)

      for text <- flashes, do: assert(bare(text) == [], "#{set.name}: #{text}")
      assert Enum.any?(flashes, &(&1 =~ ~s(class="item")))
    end

    {player, _} = Player.initialize(%Player{}, Constants.race(0), :mystic, "Sunny")
    player = %{player | sp: 10_000, experience: MiniLineage.Game.Math.xp_for_level(7)}
    {_, {:ok, learned}} = Actions.learn(player, "Wind Strike", 2)
    assert learned.text =~ Names.skill("Wind Strike", 2)
  end

  test "a page names an item or a skill in the markup a sentence does" do
    for item <- Map.values(Rules.items()) ++ Map.values(Rules.potions()) do
      assert rendered_to_string(Controls.item(%{item: item, short: false})) =~ Names.item(item)
    end

    for name <- skill_names(), level <- [nil, 3] do
      assert rendered_to_string(Controls.skill(%{name: name, level: level})) ==
               Names.skill(name, level)
    end
  end
end
