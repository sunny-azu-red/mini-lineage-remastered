defmodule MiniLineage.Scratch.Report do
  @moduledoc "Column padding and number formatting shared by the balance simulations."
  alias MiniLineage.Game.Format

  def pad(value, width), do: value |> to_string() |> String.pad_trailing(width)

  def rule(width \\ 50), do: String.duplicate("-", width)

  def fixed(number, decimals), do: :erlang.float_to_binary(number * 1.0, decimals: decimals)

  def signed(number, decimals),
    do: if(number >= 0, do: "+", else: "") <> fixed(number, decimals)

  @doc "Thousands separators, as `toLocaleString('en-US')` gave the reference scripts."
  def num(n), do: Format.number(n)
end
