defmodule MiniLineageWeb.AlertVariantsTest do
  @moduledoc """
  Every alert the game can raise has a rule to be drawn by, and every rule has an alert. A kind
  nothing styles renders unstyled and a rule nothing raises is dead weight; neither end can see
  that alone, so this reads both and compares them.
  """
  use ExUnit.Case, async: true

  alias MiniLineage.Game.{Actions, Constants, Player}

  @sheet "assets/css/components.css"

  # Every kind the game can put on an alert, and the thing a player does to see it. A refusal is
  # drawn as :danger by `GameLive`, which is the one place an error becomes an alert.
  # A new level's gold alert is drawn from the flash's `levelled`, whatever its own kind.
  defp raised do
    {_player, {:ok, welcome}} = Actions.start(%Player{}, 1, "fighter", "Newborn")
    {_player, {:error, _, _}} = Actions.start(%Player{}, 99, "fighter", "Newborn")
    {player, _} = Player.initialize(%Player{}, Constants.race(0), :fighter, "Buyer")
    {_player, {:ok, bought}} = Actions.buy(%{player | adena: 100_000}, "Broadsword")
    {_player, {:ok, %{levelled: _}}} = Actions.dev_level(player)

    MapSet.new([welcome.type, bought.type, :triumph, :danger])
  end

  defp styled do
    @sheet
    |> File.read!()
    |> then(&Regex.scan(~r/^\.alert-([a-z]+)\s*\{/m, &1))
    |> MapSet.new(fn [_, name] -> String.to_atom(name) end)
  end

  test "the alerts the game raises are exactly the ones the stylesheet draws" do
    assert raised() == styled()
  end
end
