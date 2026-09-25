defmodule MiniLineage.Game.Actions do
  @moduledoc """
  Every state-changing action, as a function from a player to `{player, result}` — the shape
  `Characters.mutate/2` runs inside the character's process.

  Each declares its own preconditions. Client-side routing is convenience; these guards are the
  boundary. Notably `restart/1` requires a dead character, so a living one can never be wiped.
  """
  alias MiniLineage.Game.{Battle, Clock, Constants, Math, Narrative, Player, Statistics}

  @errors %{
    not_started: "You haven't started your journey yet, so create a character first.",
    already_started: "You already have a character. Restart if you want to begin again.",
    dead: "You are dead. There is nothing left to do but restart.",
    not_dead: "You're still alive, and this action is only for the fallen.",
    invalid: "That is not something you can do."
  }

  defp refusal(player, checks) do
    Enum.find_value(checks, fn {code, failed?} ->
      if failed?.(player), do: {player, {:error, code, @errors[code]}}
    end)
  end

  # The first failing precondition IS the result; `fun` runs only when every one of them holds.
  defp guard(player, checks, fun), do: refusal(player, checks) || fun.(player)

  defp started, do: [{:not_started, &(not Player.started?(&1))}]
  defp alive, do: started() ++ [{:dead, & &1.dead}]

  # ------------------------------------------------------------------- start

  def start(player, race_id, name) do
    guard(player, [{:already_started, &Player.started?/1}], fn player ->
      case validate_start(race_id, name) do
        :invalid -> {player, {:error, :invalid, @errors.invalid}}
        {:ok, race_id, name} -> begin(player, race_id, name)
      end
    end)
  end

  defp begin(player, race_id, name) do
    {player, flash} = Player.initialize(player, Constants.race(race_id), name)

    # Stamped here so a fresh character never renders auraless.
    {player, _} = Player.sync_zone_auras(%{player | current_screen: "home"})

    {player, {:ok, flash}}
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
  def fight(player), do: guard(player, alive(), &do_fight/1)

  defp do_fight(player) do
    # Stamped directly rather than relying on a separate screen report, which could land out of
    # order and miscompute the zone.
    {player, _} = Player.sync_zone_auras(%{player | ambushed: false, current_screen: "battle"})

    outcome = Battle.simulate(player)
    {player, level_up?} = Player.resolve_battle_outcome(player, outcome)
    outcome = %{outcome | is_level_up: level_up?}

    died = player.dead
    # Cleared above, so only a fight the run walked away from can raise it again.
    player = if died, do: player, else: roll_ambush(player)
    ambushed = player.ambushed

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

    # Persisted so a reconnect replays this exact narrative, same as the death reason. Stamped here
    # and not at the insert: a row can sit in the process buffer, and the Chronicle should say when
    # the fight happened rather than when it was written.
    last = %{narrative: narrative, at: Clock.now()}

    # A fatal fight paid nothing, so its lines, drawn to keep the dice in step, claim what never
    # happened and are not kept: the run's ending is how it ended, and no screen shows the rest.
    player =
      if died,
        do:
          Player.log(%{player | last_battle_narrative: nil}, %{
            kind: "ending",
            line: player.death_reason,
            at: last.at
          }),
        else: Player.log(%{player | last_battle_narrative: last}, %{kind: "fight", battle: last})

    # After the fight and not inside it: the Chronicle reads in the order these are pushed, and a
    # level reached before the blow that earned it reads backwards. A fatal fight levels nobody.
    player =
      if level_up? do
        level = Math.level_for_xp(player.experience)
        Player.log(player, Player.event("level_up", Narrative.build_levelled(level)))
      else
        player
      end

    # A fatal fight never levels, so a level-up flash is never a dead one.
    flash =
      if level_up? do
        %{
          text:
            "🎉 Congratulations! You have reached level #{Math.level_for_xp(player.experience)}.",
          type: :warning,
          sound: nil
        }
      end

    {player, {:ok, %{flash: flash, sound: sound}}}
  end

  defp roll_ambush(player) do
    if Math.ambush_chance?(Player.stats(player).ambush_risk) do
      player = %{
        player
        | ambushed: true,
          total_ambushes: player.total_ambushes + 1,
          consecutive_ambushes: player.consecutive_ambushes + 1
      }

      Statistics.increment_for(player, :total_ambushes)

      if player.consecutive_ambushes >= 2,
        do: Player.apply_effect(player, Constants.effect(:ambush_debuff)),
        else: player
    else
      %{player | consecutive_ambushes: 0}
    end
  end

  # -------------------------------------------------------------------- shop

  def purchase(player, type, item_id) do
    guard(player, alive(), fn player ->
      case validate_item(type, item_id) do
        :invalid -> {player, {:error, :invalid, "Unknown item."}}
        {:ok, item_id} -> do_purchase(player, type, item_id)
      end
    end)
  end

  # The boundary, not a convenience: it rejects anything that is not a number, and the starting
  # weapon and armor, which cost nothing and are never for sale — buying one would be a free
  # downgrade.
  defp validate_item(type, item_id) do
    with {id, ""} <- Integer.parse(to_string(item_id)),
         true <- id in purchasable_ids(type) do
      {:ok, id}
    else
      _ -> :invalid
    end
  end

  defp purchasable_ids("weapon"), do: Enum.map(tl(Constants.weapons()), & &1.id)
  defp purchasable_ids("armor"), do: Enum.map(tl(Constants.armors()), & &1.id)
  defp purchasable_ids("food"), do: Enum.map(Constants.foods(), & &1.id)
  defp purchasable_ids(_type), do: []

  defp do_purchase(player, type, item_id) do
    {player, result} = Player.purchase(player, type, item_id)

    # "Not enough 🪙 Adena" and "already own this" are successful actions with a danger flash, not
    # errors.
    sound = if result.success, do: if(type == "food", do: "eat", else: "buy")
    type_atom = if result.success, do: :success, else: :danger

    {player, {:ok, %{text: result.text, type: type_atom, sound: sound}}}
  end

  # ------------------------------------------------------------------ player

  def suicide(player) do
    guard(player, alive(), fn player ->
      player = Player.commit_suicide(player)

      # A run that ends in a fight has the fight row to say so; this one needs an ending of its own.
      player = Player.log(player, Player.event("ending", player.death_reason))
      Statistics.increment(:total_players_suicided)

      {%{player | current_screen: "death"}, {:ok, nil}}
    end)
  end

  # No `alive` guard: a dead player is pinned to 'death' anyway, and dead players get no aura, so
  # recording their screen is harmless.
  def set_screen(player, screen) do
    guard(player, started(), fn player ->
      {player, _} = Player.sync_zone_auras(%{player | current_screen: screen})
      {player, {:ok, nil}}
    end)
  end

  # -------------------------------------------------------------- end of run

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
      player = Player.log(player, Player.event("cheat", Narrative.build_heresy()))
      Statistics.increment(:total_players_cheated)

      {player, {:ok, nil}}
    end
  end

  @doc "Only the fallen may start over. `Characters.archive/1` does the leaving behind."
  def may_restart?(player), do: refusal(player, [{:not_dead, &(not &1.dead)}]) == nil
end
