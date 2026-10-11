defmodule MiniLineage.Game.Shop do
  @moduledoc """
  Rules §23 and §24: what a village's traders ask and pay, and what putting an item on takes off.
  Pure, like `Hunt`: the actions in `Actions` decide what is allowed and write nothing here.
  """
  alias MiniLineage.Game.Rules

  @doc "§24: an item's price at a village shop, its canon price."
  def price(item), do: item.price

  @doc "§24: what a shop pays back for an item, half its price, and nothing for a starting kit."
  def buyback(%{sold: :starting}), do: 0
  def buyback(item), do: div(item.price, 2)

  @doc "§24: whether the shop in `town` sells `item`."
  def stocks?(town, item), do: Enum.any?(Rules.stock(town), &(&1.name == item.name))

  @doc """
  §23: the items with `id` put on, and whatever it displaces taken off: the slot's last occupant, and
  the shield for a two-handed weapon or the reverse.
  """
  def put_on(items, id) do
    item = Rules.item(Enum.find(items, &(&1.id == id)).name)

    displaced =
      items
      |> Enum.filter(&(&1.equipped and &1.id != id))
      |> Enum.map(&{&1, Rules.item(&1.name)})
      |> displaced_by(item)

    Enum.map(items, fn entry ->
      cond do
        entry.id == id -> %{entry | equipped: true}
        entry.id in displaced -> %{entry | equipped: false}
        true -> entry
      end
    end)
  end

  defp displaced_by(worn, item) do
    same = for {entry, other} <- worn, other.slot == item.slot, do: entry.id

    hands =
      for {entry, other} <- worn,
          (item.slot == :shield and other.slot == :weapon and other.hands == 2) or
            (item.slot == :weapon and item.hands == 2 and other.slot == :shield),
          do: entry.id

    same ++ hands
  end
end
