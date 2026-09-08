defmodule MiniLineage.Game.Battle do
  @moduledoc """
  Port of battle.service.ts. Every roll is bound to its own variable in the order the reference
  draws it — crit, enemy count, hp lost, xp, adena — because that order is pinned by the golden
  master and Elixir makes no promise about operand evaluation order.
  """
  alias MiniLineage.Game.{Constants, Math, Player}

  def simulate(player) do
    cfg = Constants.battle()
    stats = Player.stats(player)
    attack = stats.attack

    is_critical = Math.crit_chance?(stats.crit)

    # Enemies killed scales with attack power; a crit multiplies the whole group.
    range = Math.enemy_count_range(attack, cfg.enemy_count.min_mult, cfg.enemy_count.max_mult)
    rolled = Math.random_int(range.min, range.max)

    enemies_killed =
      if is_critical,
        do: max(cfg.crit_reward.floor, ceil(rolled * cfg.crit_reward.multiplier)),
        else: rolled

    # Danger scales linearly with attack, armor mitigates sub-linearly.
    blocked =
      Math.damage_blocked(stats.defense, cfg.damage_blocked.exponent, cfg.damage_blocked.scaling)

    hp_roll = Math.random_int(cfg.hp_lost.base_min, cfg.hp_lost.base_max)
    danger = Math.danger_level(attack, cfg.danger_level.scaling)
    hp_lost = max(cfg.hp_lost.floor, hp_roll + danger - blocked)

    # Crits multiply total rewards so they stay impactful at every attack tier.
    crit_scale = if is_critical, do: cfg.crit_reward.multiplier, else: 1

    xp_roll = Math.random_int(cfg.xp_gained.kill_min, cfg.xp_gained.kill_max)
    xp_base = Math.base_xp_gained(attack, cfg.xp_gained.exponent, cfg.xp_gained.scaling)

    xp_gained =
      ceil(ceil((enemies_killed * xp_roll + xp_base) * crit_scale) * stats.xp_multiplier)

    adena_roll = Math.random_int(cfg.adena_gained.kill_min, cfg.adena_gained.kill_max)

    adena_base =
      Math.base_adena_gained(attack, cfg.adena_gained.exponent, cfg.adena_gained.scaling)

    adena_gained =
      ceil(ceil((enemies_killed * adena_roll + adena_base) * crit_scale) * stats.adena_multiplier)

    %{
      enemies_killed: enemies_killed,
      hp_lost: hp_lost,
      damage_blocked: blocked,
      xp_gained: xp_gained,
      adena_gained: adena_gained,
      is_critical: is_critical,
      is_level_up: false
    }
  end
end
