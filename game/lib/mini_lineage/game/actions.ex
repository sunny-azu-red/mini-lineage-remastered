defmodule MiniLineage.Game.Actions do
  @moduledoc """
  Every state-changing action, as a function from a player to `{player, result}` — the shape
  `Characters.mutate/2` runs inside the character's process.

  Each declares its own preconditions. Client-side routing is convenience; these guards are the
  boundary. Notably `restart/1` requires a dead character, so a living one can never be wiped.
  """
  alias MiniLineage.Game.{Battle, Constants, Math, Narrative, Player, Statistics}
  alias MiniLineage.Highscores

  @errors %{
    not_started: "You haven't started your journey yet — create a character first.",
    already_started: "You already have a character. Restart if you want to begin again.",
    dead: "You are dead. There is nothing left to do but restart.",
    not_dead: "You're still alive — this action is only for the fallen.",
    ineligible: "Cowards and cheaters cannot be immortalized on the highscores.",
    invalid: "That is not something you can do."
  }

  defp guard(player, checks) do
    Enum.find_value(checks, fn {code, failed?} ->
      if failed?.(player), do: {player, {:error, code, @errors[code]}}
    end)
  end

  defp started, do: [{:not_started, &(not Player.started?(&1))}]
  defp alive, do: started() ++ [{:dead, & &1.dead}]

  # ------------------------------------------------------------------- start

  def start(player, race_id, name) do
    with nil <- guard(player, [{:already_started, &Player.started?/1}]),
         {:ok, race_id, name} <- validate_start(race_id, name) do
      {player, flash} = Player.initialize(player, Constants.race(race_id), name)

      # Stamped here so a fresh character never renders auraless.
      {player, _} = Player.sync_zone_auras(%{player | current_screen: "home"})

      {player, {:ok, flash}}
    else
      {_player, _error} = refusal -> refusal
      :invalid -> {player, {:error, :invalid, @errors.invalid}}
    end
  end

  defp validate_start(race_id, name) do
    config = Constants.character()
    trimmed = String.trim(to_string(name))
    length = String.length(trimmed)

    with {race_id, ""} <- Integer.parse(to_string(race_id)),
         true <- Enum.any?(Constants.races(), &(&1.id == race_id)),
         true <- length >= config.name_min_length and length <= config.name_max_length do
      {:ok, race_id, trimmed}
    else
      _ -> :invalid
    end
  end

  # ------------------------------------------------------------------ battle

  @doc """
  Succeeds identically whether or not `ambushed` was already true — an ambush is resolved by
  fighting again, with no penalty for having navigated away. Simulation runs ONLY from here,
  never on mount, reconnect or page load.
  """
  def fight(player) do
    case guard(player, alive()) do
      nil -> do_fight(player)
      refusal -> refusal
    end
  end

  defp do_fight(player) do
    # Stamped directly rather than relying on a separate screen report, which could land out of
    # order and miscompute the zone.
    {player, _} = Player.sync_zone_auras(%{player | ambushed: false, current_screen: "battle"})

    outcome = Battle.simulate(player)
    {player, level_up?} = Player.resolve_battle_outcome(player, outcome)
    outcome = %{outcome | is_level_up: level_up?}

    died = player.dead
    player = if died, do: player, else: roll_ambush(player)

    ambushed = not died and player.ambushed

    # Precedence: death > level-up > ambush > crit > silence.
    sound =
      cond do
        died -> "death"
        level_up? -> "level"
        ambushed -> "ambush"
        outcome.is_critical -> "crit"
        true -> nil
      end

    narrative = Narrative.build_battle(player, outcome, ambushed)

    # Persisted so a reconnect replays this exact narrative, same as the death reason.
    last = %{narrative: narrative, outcome: outcome, ambushed: ambushed, died: died, sound: sound}
    player = %{player | last_battle_narrative: last}

    flash =
      if not died and level_up? do
        %{
          text:
            "🎉 Congratulations! You have reached level #{Math.level_for_xp(player.experience)}.",
          type: :warning,
          sound: nil
        }
      end

    {player,
     {:ok,
      %{
        outcome: outcome,
        narrative: narrative,
        ambushed: ambushed,
        died: died,
        sound: sound,
        flash: flash
      }}}
  end

  defp roll_ambush(player) do
    if Math.ambush_chance?(Player.stats(player).ambush_risk) do
      player = %{
        player
        | ambushed: true,
          total_ambushes: player.total_ambushes + 1,
          consecutive_ambushes: player.consecutive_ambushes + 1
      }

      Statistics.increment(:total_ambushes)

      if player.consecutive_ambushes >= 2,
        do: Player.apply_effect(player, Constants.effect(:ambush_debuff)),
        else: player
    else
      %{player | consecutive_ambushes: 0}
    end
  end

  # -------------------------------------------------------------------- shop

  def purchase(player, type, item_id) do
    case guard(player, alive()) do
      nil ->
        case Player.purchase(player, type, item_id) do
          nil ->
            {player, {:error, :invalid, "Unknown item."}}

          {player, result} ->
            # "Not enough Adena" and "already own this" are successful actions with a danger
            # flash, not errors.
            sound = if result.success, do: if(type == "food", do: "eat", else: "buy")
            type_atom = if result.success, do: :success, else: :danger

            {player, {:ok, %{text: result.text, type: type_atom, sound: sound}}}
        end

      refusal ->
        refusal
    end
  end

  # ------------------------------------------------------------------ player

  def suicide(player) do
    case guard(player, alive()) do
      nil ->
        player = Player.commit_suicide(player)
        Statistics.increment(:total_players_suicided)

        {%{player | current_screen: "death"}, {:ok, nil}}

      refusal ->
        refusal
    end
  end

  # No `alive` guard: a dead player is pinned to 'death' anyway, and dead players get no aura, so
  # recording their screen is harmless.
  def set_screen(player, screen) do
    case guard(player, started()) do
      nil ->
        {player, _} = Player.sync_zone_auras(%{player | current_screen: screen})
        {player, {:ok, nil}}

      refusal ->
        refusal
    end
  end

  # -------------------------------------------------------------- end of run

  def submit_highscore(player) do
    checks =
      started() ++
        [{:not_dead, &(not &1.dead)}, {:ineligible, &(&1.coward or &1.cheated)}]

    case guard(player, checks) do
      nil ->
        Highscores.insert(%{
          name: player.name,
          experience: player.experience,
          race_id: player.race_id,
          adena: player.adena,
          level: Math.level_for_xp(player.experience)
        })

        slug = MiniLineage.Game.Format.slugify(Constants.race(player.race_id).label)

        {Player.reset(player), {:ok, %{race_slug: slug}}}

      refusal ->
        refusal
    end
  end

  @doc """
  Konami cheat. Activation is silent by design: no flash, just the debuff icon and HP snapping to
  full. Every failure path is a no-op — the relay has no ack to report one to.
  """
  def cheat(player) do
    if not Player.started?(player) or player.dead do
      {player, {:ok, nil}}
    else
      player = %{player | cheated: true}
      player = Player.apply_effect(player, Constants.effect(:konami_cheat))
      player = %{player | health: Player.stats(player).max_health}
      Statistics.increment(:total_players_cheated)

      {player, {:ok, nil}}
    end
  end

  @doc "Only the fallen may start over — a living character can never be wiped."
  def restart(player) do
    case guard(player, [{:not_dead, &(not &1.dead)}]) do
      nil -> {Player.reset(player), {:ok, nil}}
      refusal -> refusal
    end
  end
end
