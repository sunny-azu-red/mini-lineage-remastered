defmodule MiniLineage.Game.Dyes do
  @moduledoc """
  The dyes, limited to the four races' classes and kept in `priv/data/dyes.json`. A run
  stores a dye by its id and this catalog says what it does, the way an effect is stored.
  Drawing one takes `wear_count` of the dye and the Symbol Maker's fee; there is no bag, so the
  dyes are bought in the same breath.
  """

  @external_resource Path.expand("../../../priv/data/dyes.json", __DIR__)

  @dyes @external_resource
        |> hd()
        |> File.read!()
        |> Jason.decode!(keys: :atoms)
        |> Enum.map(fn dye -> Map.merge(Map.delete(dye, :stats), dye.stats) end)

  @by_id Map.new(@dyes, &{&1.id, &1})

  @attributes ~w(str con dex int wit men)a

  def all, do: @dyes
  def get(id), do: Map.fetch!(@by_id, id)
  def fetch(id), do: Map.fetch(@by_id, id)

  def for_class(class_id), do: Enum.filter(@dyes, &(class_id in &1.classes))

  @doc "Adena to have one drawn: the dyes it takes and the fee."
  def cost(dye), do: dye.wear_count * dye.dye_price + dye.wear_fee

  @doc "The attribute it raises and the one it lowers, as `{attr, amount}` pairs."
  def changes(dye),
    do: for(attr <- @attributes, dye[attr] != 0, do: {attr, dye[attr]})

  @doc "Slots a class has: none before the first transfer, two after it, three after the second."
  def slots(%{level: 1}), do: 0
  def slots(%{level: 20}), do: 2
  def slots(%{level: 40}), do: 3
end
