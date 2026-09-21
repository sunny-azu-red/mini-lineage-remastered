defmodule MiniLineageWeb.AlertVariantsTest do
  @moduledoc """
  Every alert the game can raise has a rule to be drawn by, and every rule has an alert.

  `flash_alert/1` builds its class from the type the action returned — `alert-\#{@flash.type}` — so
  a type nothing styles renders unstyled, and a rule nothing raises is dead weight in the sheet.
  Neither is visible from either side alone: grepping the stylesheet cannot see a type decided by
  `if result.success, do: :success, else: :danger`, and grepping for that atom cannot see whether
  anything draws it. This reads both ends and compares them.
  """
  use ExUnit.Case, async: true

  alias MiniLineage.Game.{Actions, Constants, Math, Player}

  @sheet "assets/css/components.css"

  defp flash_type(fun) do
    {_player, {:ok, flash}} = fun.()
    flash.type
  end

  defp rich(screen) do
    {player, _} = Player.initialize(%Player{}, Constants.race(1), "Buyer")
    %{player | adena: 100_000, current_screen: screen}
  end

  # Every variant the game can put on an alert, and the thing a player does to see it.
  defp raised do
    %{
      success: flash_type(fn -> Actions.purchase(rich("weapons"), "weapon", 1) end),
      danger: flash_type(fn -> Actions.purchase(%{rich("weapons") | adena: 0}, "weapon", 5) end),
      info: elem(Player.initialize(%Player{}, Constants.race(1), "Newborn"), 1).type,
      warning: levelled()
    }
  end

  # A fight carries its flash only when it crossed a level, so the fighter is stood one XP short of
  # the next one. Any fight at all clears it, whatever the dice do with the rest of the roll.
  defp levelled do
    fighter = %{rich("battle") | experience: Math.xp_for_level(2) - 1, health: 500}
    {_player, {:ok, result}} = Actions.fight(fighter)

    result.flash.type
  end

  defp styled do
    @sheet
    |> File.read!()
    |> then(&Regex.scan(~r/^\.alert-([a-z]+)\s*\{/m, &1))
    |> Enum.map(fn [_, name] -> String.to_atom(name) end)
    |> MapSet.new()
  end

  test "every alert the game raises is one the stylesheet draws" do
    for {expected, actual} <- raised() do
      assert actual == expected, "the #{expected} path now raises #{inspect(actual)}"
      assert actual in styled(), "nothing in #{@sheet} draws .alert-#{actual}"
    end
  end

  # `.alert-dismissible` is a modifier and `.alert-dismiss` is the corner glyph that closes one.
  # Both are parts of an alert rather than voices it can speak in, so neither answers to a type.
  @not_voices MapSet.new([:dismissible, :dismiss])

  test "and every one the stylesheet draws is one the game can raise" do
    unclaimed =
      styled()
      |> MapSet.difference(MapSet.new(Map.keys(raised())))
      |> MapSet.difference(@not_voices)

    assert Enum.to_list(unclaimed) == [], "nothing raises these"
  end
end
