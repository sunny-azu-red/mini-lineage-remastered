defmodule MiniLineageWeb.StatusPanelTest do
  @moduledoc """
  The sidebar, which every screen carries.

  Its figures animate, which means each is its own element rather than a number inside a sentence
  — and the race line puts one inside an anchor, where HEEx renders a newline as a space and the
  underline runs through whatever it finds.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias MiniLineage.Game.{Constants, Player, Snapshot}

  defp sidebar_for(player) do
    render_component(&MiniLineageWeb.Layouts.app/1,
      title: "Home Town",
      view: Snapshot.build(player),
      screen: "home",
      character_id: "abc",
      inner_block: [%{inner_block: fn _, _ -> "" end, __slot__: :inner_block}]
    )
  end

  defp text(html), do: html |> String.replace(~r/<[^>]+>/, "") |> String.replace(~r/\s+/, " ")

  setup do
    {player, _} = Player.initialize(%Player{}, Constants.race(3), "Sunny")

    %{html: sidebar_for(%{player | experience: 4200})}
  end

  test "reads as one line, whatever the markup underneath it", %{html: html} do
    assert text(html) =~ "Dark Elf level 5"
  end

  test "and leaves no space in front of any punctuation", %{html: html} do
    assert Regex.scan(~r/\S+ [,.]/, text(html)) == [], text(html)
  end

  test "every figure it shows is one the hook can count", %{html: html} do
    keys = Regex.scan(~r/data-key="([^"]+)"/, html) |> Enum.map(&List.last/1)

    assert Enum.sort(keys) == ~w(adena hp level max-hp xp xp-required)
  end

  test "the level is its own element, so it counts rather than jumps", %{html: html} do
    assert html =~ ~r|level\s+<span[^>]*data-key="level"[^>]*>5</span></a>|
  end

  test "and so is what the gear grants, which only appears once there is gear that grants" do
    crit? = &((Snapshot.item_view(&1)[:crit] || 0) > 0)
    regen? = &((Snapshot.item_view(&1)[:regen] || 0) > 0)
    {player, _} = Player.initialize(%Player{}, Constants.race(3), "Sunny")

    html =
      sidebar_for(%{
        player
        | weapon_id: Enum.find_index(Constants.weapons(), crit?),
          armor_id: Enum.find_index(Constants.armors(), regen?)
      })

    assert html =~ ~s|data-key="weapon-crit"|
    assert html =~ ~s|data-key="armor-regen"|
    assert Regex.scan(~r/\S+ [,.%]/, text(html)) == [], text(html)
  end
end
