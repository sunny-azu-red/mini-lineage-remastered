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

    sign <>
      String.replace(:erlang.float_to_binary(calculated, decimals: 1), ".0", "", global: false) <>
      unit
  end

  @doc """
  An effect's remaining time, as the icon wears it: seconds until a minute, whole minutes after.
  Twinned with `timerLabel` in `hooks/effect-timers.js`, which repaints this every second.
  """
  def countdown(remaining_ms) do
    seconds = max(0, ceil(remaining_ms / 1000))

    if seconds >= 60, do: "#{div(seconds, 60)}m", else: Integer.to_string(seconds)
  end

  @doc """
  The same time said in a sentence rather than on a badge: "4m 37s", "5m", "37s". Twinned with
  `remainingLabel` in `hooks/effect-timers.js`, which repaints this every second.
  """
  def remaining(remaining_ms) do
    seconds = max(0, ceil(remaining_ms / 1000))
    {minutes, rest} = {div(seconds, 60), rem(seconds, 60)}

    cond do
      minutes == 0 -> "#{rest}s"
      rest == 0 -> "#{minutes}m"
      true -> "#{minutes}m #{rest}s"
    end
  end

  @months ~w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)
  @full_months ~w(January February March April May June July August September October November December)

  @doc """
  When something happened, as `<.stamp>` says it: an age inside `cap_ms`, a date past it, shaped by
  `on:`, `time:` and `at_time:`. UTC, and twinned with `stampLabel` in `hooks/stamps.js`, which
  repaints it in the reader's own zone.
  """
  def stamp(at_ms, now_ms, cap_ms, form, opts \\ []) do
    age = now_ms - at_ms

    cond do
      age >= cap_ms -> absolute(at_ms, now_ms, form, opts)
      age < 60_000 -> "just now"
      age < 3_600_000 -> ago(div(age, 60_000), "m", "minute", form)
      age < 86_400_000 -> ago(div(age, 3_600_000), "h", "hour", form)
      true -> ago(div(age, 86_400_000), "d", "day", form)
    end
  end

  @doc "The whole instant, for a stamp's tooltip: \"29 Sep 2026, 3:10 pm\". Twinned with `stampTitle`."
  def stamp_title(at_ms) do
    at = DateTime.from_unix!(at_ms, :millisecond)
    "#{day(at)} #{at.year}, #{clock(at)}"
  end

  defp ago(n, unit, _word, :short), do: "#{n}#{unit} ago"
  defp ago(1, _unit, "hour", :long), do: "an hour ago"
  defp ago(1, _unit, word, :long), do: "a #{word} ago"
  defp ago(n, _unit, word, :long), do: "#{n} #{word}s ago"

  defp absolute(at_ms, now_ms, form, opts) do
    at = DateTime.from_unix!(at_ms, :millisecond)

    year =
      if at.year == DateTime.from_unix!(now_ms, :millisecond).year, do: "", else: " #{at.year}"

    time =
      cond do
        !opts[:time] -> ""
        opts[:at_time] -> " at #{clock(at)}"
        true -> ", #{clock(at)}"
      end

    if(opts[:on], do: "on ", else: "") <> "#{day(at, form)}#{year}#{time}"
  end

  defp day(at, form \\ :short)
  defp day(at, :short), do: "#{at.day} #{Enum.at(@months, at.month - 1)}"
  defp day(at, :long), do: "#{at.day} #{Enum.at(@full_months, at.month - 1)}"

  # Twelve-hour, and the game's own rather than the browser's locale, so the two sides agree.
  defp clock(at) do
    hour = if rem(at.hour, 12) == 0, do: 12, else: rem(at.hour, 12)
    minute = String.pad_leading(Integer.to_string(at.minute), 2, "0")
    "#{hour}:#{minute} #{if at.hour < 12, do: "am", else: "pm"}"
  end

  @doc "A modifier as a reader meets it: a multiplier bare, anything else carrying its own sign."
  def modifier(value, multiplier? \\ false)
  def modifier(value, true), do: number(value)
  def modifier(value, _additive) when value > 0, do: "+" <> number(value)
  def modifier(value, _additive), do: number(value)

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
  Fills `{key}` and `{key ? 'yes' : 'no'}`. An unknown key is left verbatim, so open pronouns
  survive until render.
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
