# Two readings of bench/ladder.exs --json, the same settings on two builds, set against the bar a
# fight change must clear: no set dies when it rests to full, no set's road to the top level moves
# more than 15% either way, deaths do not rise beyond the dice's noise, and the spread between the
# fastest and slowest set does not widen by more than 2%, which the dice alone can do.
#
#   mix run --no-start bench/compare.exs before.json after.json

[before_path, after_path] = System.argv()
read = fn path -> path |> File.read!() |> JSON.decode!() end
before = read.(before_path)
after_ = read.(after_path)

if before["settings"] != after_["settings"],
  do: raise("the two readings were taken with different settings")

settings = after_["settings"]
rested? = settings["rest_below"] == 100
key = &{&1["set"], &1["path"]}
befores = Map.new(before["rows"], &{key.(&1), &1})

pct = fn
  nil, _ -> nil
  _, nil -> nil
  b, a -> (a - b) / b * 100
end

fmt = fn
  nil -> "-"
  x when is_float(x) -> :erlang.float_to_binary(x, decimals: 1)
  x -> to_string(x)
end

# Two counts of n runs differ by more than the dice explain when the gap passes twice the standard
# deviation of the difference of two binomials at their pooled rate.
noise = fn b, a, n ->
  p = (b + a) / (2 * n)
  2 * :math.sqrt(2 * n * p * (1 - p))
end

{lines, faults} =
  Enum.map_reduce(after_["rows"], [], fn row, faults ->
    was = Map.fetch!(befores, key.(row))
    n = row["runs"]
    moved = pct.(was["minutes"], row["minutes"])

    faults =
      faults
      |> then(
        &if rested? and row["deaths"] > 0,
          do: ["#{row["set"]}, #{row["path"]} dies at the defaults" | &1],
          else: &1
      )
      |> then(
        &if row["deaths"] - was["deaths"] > max(noise.(was["deaths"], row["deaths"], n), 1),
          do: [
            "#{row["set"]}, #{row["path"]} dies more: #{was["deaths"]} to #{row["deaths"]} of #{n}"
            | &1
          ],
          else: &1
      )
      |> then(
        &if moved && abs(moved) > 15,
          do: ["#{row["set"]}, #{row["path"]} takes #{fmt.(moved)}% to the top" | &1],
          else: &1
      )

    line =
      String.pad_trailing("#{row["set"]}, #{row["path"]}", 30) <>
        " died #{was["deaths"]} -> #{row["deaths"]} of #{n}" <>
        " | minutes #{fmt.(was["minutes"])} -> #{fmt.(row["minutes"])} (#{fmt.(moved)}%)" <>
        " | rest #{fmt.(was["rest_minutes"])} -> #{fmt.(row["rest_minutes"])}" <>
        " | rounds a fight #{fmt.(was["rounds_a_fight"])} -> #{fmt.(row["rounds_a_fight"])}" <>
        " | potions #{fmt.(was["potions"])} -> #{fmt.(row["potions"])}"

    {line, faults}
  end)

spread = fn rows ->
  case rows |> Enum.map(& &1["minutes"]) |> Enum.reject(&is_nil/1) do
    [] -> nil
    minutes -> Enum.max(minutes) - Enum.min(minutes)
  end
end

{was_spread, now_spread} = {spread.(before["rows"]), spread.(after_["rows"])}

faults =
  if was_spread && now_spread && now_spread > was_spread * 1.02,
    do: ["the spread widens: #{fmt.(was_spread)} to #{fmt.(now_spread)} minutes" | faults],
    else: faults

IO.puts("Settings: #{inspect(settings)}")
Enum.each(lines, &IO.puts/1)
IO.puts("Spread, fastest to slowest set: #{fmt.(was_spread)} -> #{fmt.(now_spread)} minutes")

case Enum.reverse(faults) do
  [] -> IO.puts("PASS")
  found -> IO.puts("FAIL\n  " <> Enum.join(found, "\n  "))
end
