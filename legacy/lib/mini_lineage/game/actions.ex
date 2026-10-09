defmodule MiniLineage.Game.Actions do
  @moduledoc """
  Every state-changing action, as a function from a player to `{player, result}` — the shape
  `Characters.mutate/2` runs inside the character's process. Each declares its own preconditions:
  client-side routing is convenience, these guards are the boundary.
  """
  alias MiniLineage.Game.{
    Battle,
    Classes,
    Clock,
    Constants,
    Dyes,
    Math,
    Narrative,
    Player,
    Statistics
  }

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

  def start(player, race_id, archetype, name) do
    guard(player, [{:already_started, &Player.started?/1}], fn player ->
      case validate_start(race_id, archetype, name) do
        :invalid -> {player, {:error, :invalid, @errors.invalid}}
        {:ok, race_id, archetype, name} -> begin(player, race_id, archetype, name)
      end
    end)
  end

  defp begin(player, race_id, archetype, name) do
    {player, flash} = Player.initialize(player, Constants.race(race_id), archetype, name)

    # Stamped here so a fresh character never renders auraless.
    {player, _} = Player.sync_zone_auras(%{player | current_screen: "home"})

    {player, {:ok, flash}}
  end

  defp validate_start(race_id, archetype, name) do
    config = Constants.character()
    trimmed = String.trim(to_string(name))
    length = String.length(trimmed)

    with {race_id, ""} <- Integer.parse(to_string(race_id)),
         true <- Enum.any?(Constants.races(), &(&1.id == race_id)),
         {:ok, archetype} <- archetype(archetype),
         true <- length >= config.name_min_length and length <= config.name_max_length do
      {:ok, race_id, archetype, trimmed}
    else
      _ -> :invalid
    end
  end

  # Named here rather than converted: the form's value is untrusted, and `String.to_atom/1` on it
  # would mint atoms.
  defp archetype("fighter"), do: {:ok, :fighter}
  defp archetype("mystic"), do: {:ok, :mystic}
  defp archetype(_other), do: :invalid

  # ------------------------------------------------------------------ battle

  @doc "Simulation runs ONLY from here, never on mount, reconnect or page load."
  def fight(player), do: guard(player, alive(), &do_fight/1)

  defp do_fight(player) do
    # Stamped directly rather than relying on a separate screen report, which could land out of
    # order and miscompute the zone.
    {player, _} = Player.sync_zone_auras(%{player | current_screen: "battle"})

    outcome = Battle.simulate(player)
    {player, level_up?} = Player.resolve_battle_outcome(player, outcome)
    outcome = %{outcome | is_level_up: level_up?}

    died = player.dead

    sound =
      cond do
        died -> "death"
        level_up? -> "level"
        outcome.is_critical -> "crit"
        true -> nil
      end

    narrative = Narrative.build_battle(player, outcome)

    # Stamped here, not at the insert: a row can sit in the process buffer, and the Chronicle says
    # when the fight happened rather than when it was written.
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

  # -------------------------------------------------------------------- shop

  def purchase(player, type, item_id) do
    guard(player, alive(), fn player ->
      case validate_item(type, item_id) do
        :invalid -> {player, {:error, :invalid, "Unknown item."}}
        {:ok, item_id} -> do_purchase(player, type, item_id)
      end
    end)
  end

  # The boundary: rejects anything not a number, and the starting weapon and armor, which are
  # never for sale — buying one would be a free downgrade.
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

    # "Not enough 🪙 Adena" and "already own this" are successful actions with a danger flash.
    sound = if result.success, do: if(type == "food", do: "eat", else: "buy")
    type_atom = if result.success, do: :success, else: :danger

    {player, {:ok, %{text: result.text, type: type_atom, sound: sound}}}
  end

  # ------------------------------------------------------------------ classes

  @doc "Takes up one of the classes the run's own class leads to, once its level allows."
  def transfer(player, class_id) do
    guard(player, alive(), fn player ->
      with {:ok, class} <- next_class(player, class_id),
           :ok <- reached(player, class.level) do
        {player, line} = Player.transfer(player, class)
        {player, {:ok, %{text: Narrative.alert(line), type: :warning, sound: "level"}}}
      else
        {:error, code, message} -> {player, {:error, code, message}}
      end
    end)
  end

  defp next_class(player, class_id) do
    with {id, ""} <- Integer.parse(to_string(class_id)),
         {:ok, class} <- Classes.fetch(id),
         true <- class.parent_id == Player.class_id(player) do
      {:ok, class}
    else
      _ -> {:error, :invalid, "That is not a calling your class leads to."}
    end
  end

  defp reached(player, level) do
    if Math.level_for_xp(player.experience) >= level,
      do: :ok,
      else: {:error, :too_low, "You must reach level #{level} before you can take it up."}
  end

  # -------------------------------------------------------------------- dyes

  @doc "Draws a dye into a free slot, paying for the dyes it takes and the Symbol Maker's fee."
  def draw_dye(player, dye_id) do
    guard(player, alive(), fn player ->
      class = Classes.get(Player.class_id(player))
      slots = Dyes.slots(class)

      with :ok <- slot_free(player, slots),
           {:ok, dye} <- dye_for(class, dye_id) do
        player |> Player.draw_dye(dye) |> dye_result("dye")
      else
        {:error, code, message} -> {player, {:error, code, message}}
      end
    end)
  end

  @doc "Washes away the dye in a slot, for the Symbol Maker's fee. Nothing comes back."
  def remove_dye(player, slot) do
    guard(player, alive(), fn player ->
      case Integer.parse(to_string(slot)) do
        {index, ""} when index >= 0 and index < length(player.dyes) ->
          player |> Player.remove_dye(index) |> dye_result("buy")

        _ ->
          {player, {:error, :invalid, "There is no symbol there to wash away."}}
      end
    end)
  end

  defp dye_for(class, dye_id) do
    with {id, ""} <- Integer.parse(to_string(dye_id)),
         {:ok, dye} <- Dyes.fetch(id),
         true <- class.id in dye.classes do
      {:ok, dye}
    else
      _ -> {:error, :invalid, "The Symbol Maker has no such dye for your class."}
    end
  end

  defp slot_free(_player, 0),
    do: {:error, :no_slots, "Symbols can be drawn only after your first class transfer."}

  defp slot_free(player, slots) do
    if length(player.dyes) < slots,
      do: :ok,
      else: {:error, :slots_full, "All #{slots} of your symbol slots are taken."}
  end

  # A refusal for want of Adena is still an answer from the Symbol Maker, as it is in a shop.
  defp dye_result({player, %{success: true, text: text}}, sound),
    do: {player, {:ok, %{text: text, type: :success, sound: sound}}}

  defp dye_result({player, %{success: false, text: text}}, _sound),
    do: {player, {:ok, %{text: text, type: :danger, sound: nil}}}

  # ------------------------------------------------------------------ player

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
    # Once, not again: a second sequence would refill health, log the heresy and count it twice.
    if not Player.started?(player) or player.dead or player.cheated do
      {player, {:ok, nil}}
    else
      player = %{player | cheated: true}
      player = Player.apply_effect(player, Constants.effect(:konami_cheat))
      player = Player.restore_fully(player)
      player = Player.log(player, Player.event("cheat", Narrative.build_heresy()))
      Statistics.increment(:total_players_cheated)

      {player, {:ok, nil}}
    end
  end

  @doc "Only the fallen may start over. `Characters.archive/1` does the leaving behind."
  def may_restart?(player), do: refusal(player, [{:not_dead, &(not &1.dead)}]) == nil
end
