defmodule MiniLineageWeb.AlertVariantsTest do
  @moduledoc """
  Every alert the game can raise has a rule to be drawn by, and every rule has an alert. A kind
  nothing styles renders unstyled and a rule nothing raises is dead weight; neither end can see
  that alone, so this reads both and compares them.
  """
  use ExUnit.Case, async: true

  alias MiniLineage.Game.{Actions, Player}

  @sheet "assets/css/components.css"

  # Every kind the game can put on an alert, and the thing a player does to see it. A refusal is
  # drawn as :danger by `GameLive`, which is the one place an error becomes an alert.
  defp raised do
    {_player, {:ok, welcome}} = Actions.start(%Player{}, 1, "fighter", "Newborn")
    {_player, {:error, _, _}} = Actions.start(%Player{}, 99, "fighter", "Newborn")

    MapSet.new([welcome.type, :danger])
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
