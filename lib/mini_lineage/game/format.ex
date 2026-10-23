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

  @doc "Tenths, a rate's or a cast's: 88 is \"8.8\". Twinned with `tenthsFigure` in animated-values.js."
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

  @doc """
  How long ago something happened: "just now", "3m ago", "2h ago", "5d ago", or `:long` for a
  sentence ("3 minutes ago"), and from `cap_ms` on the `date` the server wrote. Twinned with
  `stampLabel` in `hooks/stamp.js`.
  """
  def stamp(age_ms, cap_ms, _form, date) when age_ms >= cap_ms, do: date

  def stamp(age_ms, _cap_ms, form, _date) do
    cond do
      age_ms < 60_000 -> "just now"
      age_ms < 3_600_000 -> ago(div(age_ms, 60_000), "m", "minute", form)
      age_ms < 86_400_000 -> ago(div(age_ms, 3_600_000), "h", "hour", form)
      true -> ago(div(age_ms, 86_400_000), "d", "day", form)
    end
  end

  defp ago(n, unit, _word, :short), do: "#{n}#{unit} ago"
  defp ago(1, _unit, "hour", :long), do: "an hour ago"
  defp ago(1, _unit, word, :long), do: "a #{word} ago"
  defp ago(n, _unit, word, :long), do: "#{n} #{word}s ago"

  @doc """
  The day a stamp turns into past its cap, "17 Oct" or `:long` "17 October", the year only when it
  is not `now`'s. Both instants are already in the game's zone (`Clock.local/1`), and the browser is
  handed this rather than a zone to work it out in.
  """
  def date(%DateTime{} = at, %DateTime{} = now, form) do
    month = Calendar.strftime(at, if(form == :long, do: "%B", else: "%b"))
    year = if at.year == now.year, do: "", else: " #{at.year}"
    "#{at.day} #{month}#{year}"
  end

  @doc "The whole instant, for a stamp's tooltip: \"17 Oct 2026, 3:10 pm\", in the game's zone."
  def instant(%DateTime{} = at), do: Calendar.strftime(at, "%-d %b %Y, %-I:%M %P")

  # As Lineage II's client names them, every shortened word ending in a full stop. Block, M. Critical
  # and Recovery are ours, as docs/canon/README.md's departures say.
  @stats %{
    p_atk: "P. Atk.",
    m_atk: "M. Atk.",
    p_def: "P. Def.",
    m_def: "M. Def.",
    atk_spd: "Atk. Spd.",
    cast_spd: "Casting Spd.",
    run_spd: "Speed",
    accuracy: "Accuracy",
    evasion: "Evasion",
    critical: "Critical",
    magic_critical: "M. Critical",
    shield_def: "Shield P. Def.",
    shield_rate: "Block",
    hp_regen: "HP Recovery",
    mp_regen: "MP Recovery",
    mp: "Max MP"
  }

  @doc "A stat as every page names it: \"P. Atk.\", \"Casting Spd.\", \"Speed\"."
  def stat(key), do: Map.fetch!(@stats, key)

  @doc "A sentence's full stop, unless what ends it ends in one already: \"+16 M. Def.\"."
  def stop(text), do: if(String.ends_with?(text, "."), do: "", else: ".")

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

  @doc "Fills `{key}`. An unknown key is left verbatim, so open pronouns survive until render."
  # Without a regex, which every fight's lines ran several times over.
  def fill_template(template, data) do
    [head | rest] = String.split(template, "{")
    IO.iodata_to_binary([head | Enum.map(rest, &fill_after_brace(&1, data))])
  end

  defp fill_after_brace(piece, data) do
    with [key, tail] <- :binary.split(piece, "}"),
         true <- word?(key),
         value when value != nil <- Map.get(data, key) do
      [to_string(value), tail]
    else
      _ -> ["{", piece]
    end
  end

  # Regex's `\w+`: ASCII letters, digits and the underscore.
  defp word?(<<c, rest::binary>>) when c in ?a..?z or c in ?A..?Z or c in ?0..?9 or c == ?_,
    do: rest == "" or word?(rest)

  defp word?(_), do: false
end
