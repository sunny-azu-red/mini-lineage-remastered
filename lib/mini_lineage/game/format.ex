defmodule MiniLineage.Game.Format do
  @moduledoc "Kept dependency-free and exact — narratives read off these."

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

  @doc "999 -> \"999\", 1500 -> \"1.5k\", 2_000_000 -> \"2kk\"."
  def short(value) do
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

    sign <>
      String.replace(:erlang.float_to_binary(calculated, decimals: 1), ".0", "", global: false) <>
      unit
  end

  @doc "Whole percent, as the XP bar reads them: 54 -> \"54%\"."
  def percent(whole) when is_integer(whole) and whole >= 0, do: "#{whole}%"

  @doc "Tenths, a critical rate's: 88 is \"8.8\". Twinned with `tenthsFigure` in animated-values.js."
  def tenths(tenths) when is_integer(tenths) and tenths >= 0,
    do: "#{div(tenths, 10)}.#{rem(tenths, 10)}"

  @doc """
  Time left over an effect's icon: whole seconds, rounded up, and from a minute on whole minutes, "37"
  and "2m". Twinned with `timerLabel` in `hooks/effect-timers.js`.
  """
  def countdown(ms) do
    seconds = seconds_left(ms)
    if seconds >= 60, do: "#{div(seconds, 60)}m", else: Integer.to_string(seconds)
  end

  @doc """
  The same time said in a sentence: "1m 37s", "2m", "37s". Twinned with `remainingLabel` in
  `hooks/effect-timers.js`.
  """
  def remaining(ms) do
    seconds = seconds_left(ms)

    case {div(seconds, 60), rem(seconds, 60)} do
      {0, rest} -> "#{rest}s"
      {minutes, 0} -> "#{minutes}m"
      {minutes, rest} -> "#{minutes}m #{rest}s"
    end
  end

  defp seconds_left(ms), do: max(ceil(ms / 1000), 0)

  @doc "An amount of Adena as every message writes it: the coin, the figure and the word, in gold."
  def adena(amount), do: ~s(<span class="adena">🪙 #{number(amount)} Adena</span>)

  @doc "Names joined as a sentence says them: \"a\", \"a or b\", \"a, b or c\"."
  def list([only], _word), do: only

  def list(names, word),
    do: "#{Enum.join(Enum.drop(names, -1), ", ")} #{word} #{List.last(names)}"

  def slugify(text) do
    text
    |> String.downcase()
    |> String.trim()
    |> String.replace(~r/\s+/, "-")
    |> String.replace(~r/[^\w-]+/u, "")
    |> String.replace(~r/--+/, "-")
  end

  @placeholder ~r/\{(\w+)\}/

  @doc "Fills `{key}`. An unknown key is left verbatim, so open pronouns survive until render."
  def fill_template(template, data) do
    String.replace(template, @placeholder, fn match ->
      [_, key] = Regex.run(@placeholder, match)

      case Map.get(data, key) do
        nil -> match
        value -> to_string(value)
      end
    end)
  end
end
