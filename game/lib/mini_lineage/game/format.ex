defmodule MiniLineage.Game.Format do
  @moduledoc "Ports of shared/format.ts. Kept dependency-free and exact — narratives read off these."

  @doc "Thousands separators, matching `toLocaleString('en-US')`."
  def number(n) when is_integer(n) do
    {sign, digits} =
      case Integer.to_string(n) do
        "-" <> rest -> {"-", rest}
        rest -> {"", rest}
      end

    grouped =
      digits
      |> String.reverse()
      |> String.to_charlist()
      |> Enum.chunk_every(3)
      |> Enum.map_join(",", &List.to_string/1)
      |> String.reverse()

    sign <> grouped
  end

  def number(n) when is_float(n), do: number(trunc(n))

  @doc "999 -> \"999\", 1500 -> \"1.5k\", 2_000_000 -> \"2kk\"."
  def adena(value) do
    abs = Kernel.abs(value)
    sign = if value < 0, do: "-", else: ""

    cond do
      abs <= 999 -> Integer.to_string(value)
      abs < 1_000_000 -> short(sign, abs, 1_000, "k")
      abs < 1_000_000_000 -> short(sign, abs, 1_000_000, "kk")
      true -> short(sign, abs, 1_000_000_000, "kkk")
    end
  end

  defp short(sign, abs, divisor, unit) do
    calculated = Kernel.floor(abs / divisor * 10) / 10

    sign <> String.replace(:erlang.float_to_binary(calculated, decimals: 1), ".0", "", global: false) <> unit
  end

  def pluralize(singular, plural, count, emoji \\ nil) do
    icon = if emoji, do: "#{emoji} ", else: ""

    if count == 1 do
      article = if String.first(String.downcase(singular)) in ~w(a e i o u), do: "an", else: "a"
      "#{article} #{icon}#{singular}"
    else
      "#{number(count)} #{icon}#{plural}"
    end
  end

  def capitalize(""), do: ""
  def capitalize(text), do: String.upcase(String.first(text)) <> String.slice(text, 1..-1//1)

  def slugify(text) do
    text
    |> String.downcase()
    |> String.trim()
    |> String.replace(~r/\s+/, "-")
    |> String.replace(~r/[^\w-]+/u, "")
    |> String.replace(~r/--+/, "-")
  end

  @ternary ~r/\{(\w+)\s*\?\s*['"]([^'"]*)['"]\s*:\s*['"]([^'"]*)['"]\}/
  @placeholder ~r/\{(\w+)\}/

  @doc ~S"""
  Fills `{key}` and `{key ? 'yes' : 'no'}`. An unknown key is left verbatim, as in the reference.
  """
  def fill_template(nil, _data), do: ""
  def fill_template("", _data), do: ""

  def fill_template(template, data) do
    template
    |> String.replace(@ternary, fn match ->
      [_, key, truthy, falsy] = Regex.run(@ternary, match)
      if truthy?(Map.get(data, key)), do: truthy, else: falsy
    end)
    |> String.replace(@placeholder, fn match ->
      [_, key] = Regex.run(@placeholder, match)

      case Map.get(data, key) do
        nil -> match
        value -> to_string(value)
      end
    end)
  end

  defp truthy?(nil), do: false
  defp truthy?(false), do: false
  defp truthy?(0), do: false
  defp truthy?(""), do: false
  defp truthy?(_), do: true
end
