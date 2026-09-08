defmodule MiniLineage.Scratch.CritBalance do
  @moduledoc """
  Port of scratch/check_crit_balance.ts — the study that chose the 1.9x crit multiplier.

  It rolls its own combat rather than calling `Battle.simulate/1`, because it needs to force the
  crit branch and vary the multiplier. The draw order is Battle's, since that order is pinned by
  the golden master.
  """
  import MiniLineage.Scratch.Report
  alias MiniLineage.Game.{Constants, Math, Player}

  @tiers [
    {"Early Game", 0, 0},
    {"Mid Game", 2, 3},
    {"End Game", 4, 5}
  ]

  def run(trials \\ 10_000) do
    IO.puts("\n#{String.duplicate("=", 72)}")
    IO.puts("      CRIT MULTIPLIER COMPARISON: 1.5x vs 1.9x (#{num(trials)} iterations)")
    IO.puts("#{String.duplicate("=", 72)}\n")

    for {label, weapon_id, armor_id} <- @tiers do
      weapon = Constants.weapon(weapon_id)
      armor = Constants.armor(armor_id)

      IO.puts(rule(72))
      IO.puts("  TIER: #{label} (#{weapon.name} / #{armor.name})")
      IO.puts(rule(72))

      player = %Player{
        name: "Hero",
        race_id: 0,
        weapon_id: weapon_id,
        armor_id: armor_id,
        health: 100,
        experience: 0,
        adena: 0
      }

      normal = average_over(player, trials, 1.5, false)
      crit15 = average_over(player, trials, 1.5, true)
      crit19 = average_over(player, trials, 1.9, true)

      report("Enemies Defeated", "enemies", normal, crit15, crit19, :enemies_killed)
      report("XP Gained", "XP", normal, crit15, crit19, :xp_gained)
      report("Adena Gained", "Adena", normal, crit15, crit19, :adena_gained)
    end
  end

  defp average_over(player, trials, multiplier, critical?) do
    totals =
      Enum.reduce(1..trials, %{enemies_killed: 0, xp_gained: 0, adena_gained: 0}, fn _, acc ->
        result = combat(player, multiplier, critical?)

        %{
          enemies_killed: acc.enemies_killed + result.enemies_killed,
          xp_gained: acc.xp_gained + result.xp_gained,
          adena_gained: acc.adena_gained + result.adena_gained
        }
      end)

    Map.new(totals, fn {key, total} -> {key, total / trials} end)
  end

  defp combat(player, multiplier, critical?) do
    cfg = Constants.battle()
    stats = Player.stats(player)
    attack = stats.attack

    range = Math.enemy_count_range(attack, cfg.enemy_count.min_mult, cfg.enemy_count.max_mult)
    rolled = Math.random_int(range.min, range.max)

    enemies_killed =
      if critical?,
        do: max(cfg.crit_reward.floor, ceil(rolled * multiplier)),
        else: rolled

    blocked =
      Math.damage_blocked(stats.defense, cfg.damage_blocked.exponent, cfg.damage_blocked.scaling)

    hp_roll = Math.random_int(cfg.hp_lost.base_min, cfg.hp_lost.base_max)
    danger = Math.danger_level(attack, cfg.danger_level.scaling)
    hp_lost = max(cfg.hp_lost.floor, hp_roll + danger - blocked)

    xp_roll = Math.random_int(cfg.xp_gained.kill_min, cfg.xp_gained.kill_max)

    xp =
      enemies_killed * xp_roll +
        Math.base_xp_gained(attack, cfg.xp_gained.exponent, cfg.xp_gained.scaling)

    adena_roll = Math.random_int(cfg.adena_gained.kill_min, cfg.adena_gained.kill_max)

    adena =
      enemies_killed * adena_roll +
        Math.base_adena_gained(attack, cfg.adena_gained.exponent, cfg.adena_gained.scaling)

    %{
      enemies_killed: enemies_killed,
      hp_lost: hp_lost,
      damage_blocked: blocked,
      xp_gained: if(critical?, do: ceil(xp * multiplier), else: xp),
      adena_gained: if(critical?, do: ceil(adena * multiplier), else: adena)
    }
  end

  # Enemy counts are compared to one decimal, rewards as whole numbers — as the reference printed
  # them, so the percentages below are computed from the rounded figures it showed.
  defp report("Enemies Defeated" = heading, unit, normal, c15, c19, key) do
    n = fixed(normal[key], 1)
    a = fixed(c15[key], 1)
    b = fixed(c19[key], 1)

    IO.puts("  [#{heading}]")
    IO.puts("    Normal Hit : #{n} #{unit}")
    IO.puts("    1.5x Crit  : #{a} #{unit}  (+#{pct(a, n)}% vs normal)")

    IO.puts(
      "    1.9x Crit  : #{b} #{unit}  (+#{pct(b, n)}% vs normal) -> +#{pct(b, a)}% boost over 1.5x\n"
    )
  end

  defp report(heading, unit, normal, c15, c19, key) do
    n = Math.js_round(normal[key])
    a = Math.js_round(c15[key])
    b = Math.js_round(c19[key])

    IO.puts("  [#{heading}]")
    IO.puts("    Normal Hit : #{num(n)} #{unit}")
    IO.puts("    1.5x Crit  : #{num(a)} #{unit}  (#{fixed(a / n, 2)}x normal)")

    IO.puts(
      "    1.9x Crit  : #{num(b)} #{unit}  (#{fixed(b / n, 2)}x normal) -> +#{pct(b, a)}% more #{unit} than 1.5x\n"
    )
  end

  defp pct(value, baseline) when is_binary(value),
    do: pct(String.to_float(value), String.to_float(baseline))

  defp pct(value, baseline), do: Math.js_round((value - baseline) / baseline * 100)
end
