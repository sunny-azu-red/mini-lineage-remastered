defmodule MiniLineage.Game.Actions do
  @moduledoc """
  Every state-changing action, as a function from a player to `{player, result}` — the shape
  `Characters.mutate/2` runs inside the character's process. Each declares its own preconditions:
  client-side routing is convenience, these guards are the boundary.
  """
  alias MiniLineage.Game.{Constants, Format, Hunt, Math, Narrative, Player, Rules, Version}

  @errors %{
    already_started: "You already have a character.",
    invalid: "That is not something you can do.",
    closed: "The Gatekeeper cannot send you there yet.",
    poor: "You cannot pay the Gatekeeper's fee.",
    last_level: "There is no level past the last.",
    no_ground: "There is nothing to hunt here.",
    spent: "You are too weak to hunt, and must rest first."
  }

  # Not a rule of the game: what a debug build puts in a purse so the Gatekeeper can be tried.
  @dev_adena 10_000

  @doc "Creates the character: a race, a path and a name, all checked here."
  def start(player, race_id, path, name) do
    cond do
      Player.started?(player) ->
        {player, {:error, :already_started, @errors.already_started}}

      true ->
        case validate_start(race_id, path, name) do
          :invalid -> {player, {:error, :invalid, @errors.invalid}}
          {:ok, race, path, name} -> begin(player, race, path, name)
        end
    end
  end

  defp begin(player, race, path, name) do
    {player, flash} = Player.initialize(player, race, path, name)
    {player, {:ok, flash}}
  end

  defp validate_start(race_id, path, name) do
    config = Constants.character()
    trimmed = String.trim(to_string(name))
    length = String.length(trimmed)

    with {race_id, ""} <- Integer.parse(to_string(race_id)),
         %{} = race <- Enum.find(Constants.races(), &(&1.id == race_id)),
         {:ok, path} <- path(path),
         true <- length >= config.name_min_length and length <= config.name_max_length do
      {:ok, race, path, trimmed}
    else
      _ -> :invalid
    end
  end

  @doc "Rules §14: the Gatekeeper sends a character along a route out of its town, for the fee."
  def travel(player, to) do
    route = Player.started?(player) && Rules.route(player.location, to)

    cond do
      !route -> {player, {:error, :invalid, @errors.invalid}}
      !Rules.town(to).open? -> {player, {:error, :closed, @errors.closed}}
      player.adena < route.fee -> {player, {:error, :poor, @errors.poor}}
      true -> arrive(player, Rules.town(to), route.fee)
    end
  end

  defp arrive(player, town, fee) do
    player = %{player | location: town.slug, adena: player.adena - fee}
    {player, {:ok, %{text: Narrative.alert(Narrative.build_arrived(town, fee)), type: :info}}}
  end

  @doc """
  Rules §20: one click, one fight, on the ground of the village the character stands in. A kill
  pays EXP, SP and Adena; a death (§21) marks the run fallen, which its process then retires.
  """
  def hunt(player) do
    ground = Player.started?(player) && Rules.ground_of(player.location)

    cond do
      !ground -> {player, {:error, :no_ground, @errors.no_ground}}
      player.health <= 0 -> {player, {:error, :spent, @errors.spent}}
      true -> fight(player, ground)
    end
  end

  defp fight(player, ground) do
    level = Player.level(player)
    foe = ground |> Rules.monsters_of() |> Hunt.draw(level) |> Hunt.foe()
    skill = Rules.first_skill(player.race_id, player.path)
    result = Hunt.fight(Player.stats(player), player, skill, foe)
    player = %{player | health: result.health, mp: result.mp}

    cond do
      result.health <= 0 ->
        fell = Narrative.build_fell(foe, ground)
        player = %{player | dead: true, killer: foe.name}
        {player, {:ok, %{text: Narrative.alert(fell), type: :danger}}}

      result.foe > 0 ->
        {player,
         {:ok, %{text: Narrative.alert(Narrative.build_wandered(foe, ground)), type: :info}}}

      true ->
        reward(player, foe, ground, level)
    end
  end

  defp reward(player, foe, ground, level) do
    exp = Hunt.reward(foe.exp, level, foe.level)
    sp = Hunt.reward(foe.sp, level, foe.level)
    adena = Hunt.adena(foe)

    gained = %{
      Player.gain_experience(player, exp)
      | sp: player.sp + sp,
        adena: player.adena + adena
    }

    reached = Player.level(gained)

    text =
      Narrative.alert(Narrative.build_slew(foe, ground, exp, sp, adena)) <>
        if reached > level,
          do: " " <> Narrative.alert(Narrative.build_levelled(reached)),
          else: ""

    {gained, {:ok, %{text: text, type: :info}}}
  end

  @doc "Debug builds only: Adena to try the Gatekeeper with, every time it is asked for."
  def dev_adena(player) do
    if Version.debug_build?() and Player.started?(player) do
      text =
        ~s(A debug build drops <span class="adena">#{Format.number(@dev_adena)} Adena</span> into your purse.)

      {%{player | adena: player.adena + @dev_adena}, {:ok, %{text: text, type: :info}}}
    else
      {player, {:error, :invalid, @errors.invalid}}
    end
  end

  @doc "Debug builds only: both bars to half, and the XP bar halfway to the next level."
  def dev_half(player) do
    if Version.debug_build?() and Player.started?(player) do
      stats = Player.stats(player)
      text = "A debug build halves your HP and MP, and sets your XP halfway to the next level."

      {%{
         player
         | health: trunc(stats.max_hp / 2),
           mp: trunc(stats.max_mp / 2),
           experience: halfway(player)
       }, {:ok, %{text: text, type: :info}}}
    else
      {player, {:error, :invalid, @errors.invalid}}
    end
  end

  @doc "Debug builds only: exactly the EXP the next level needs, which refills both bars."
  def dev_level(player), do: dev_reach(player, Player.level(player) + 1)

  @doc "Debug builds only: exactly the EXP the last level needs, which refills both bars."
  def dev_max_level(player), do: dev_reach(player, Rules.max_level())

  defp dev_reach(player, target) do
    cond do
      not (Version.debug_build?() and Player.started?(player)) ->
        {player, {:error, :invalid, @errors.invalid}}

      Math.max_level?(Player.level(player)) ->
        {player, {:error, :last_level, @errors.last_level}}

      true ->
        needed = Math.xp_for_level(target) - player.experience

        text =
          ~s(A debug build hands you <span class="xp">#{Format.number(needed)} XP</span>, enough to reach <span class="level">Level #{target}</span>.)

        {Player.gain_experience(player, needed), {:ok, %{text: text, type: :info}}}
    end
  end

  # The last level has no next one to be halfway to.
  defp halfway(player) do
    level = Player.level(player)

    if Math.max_level?(level) do
      player.experience
    else
      base = Math.xp_for_level(level)
      base + div(Math.xp_for_level(level + 1) - base, 2)
    end
  end

  # Named here rather than converted: the form's value is untrusted, and `String.to_atom/1` on it
  # would mint atoms.
  defp path("fighter"), do: {:ok, :fighter}
  defp path("mystic"), do: {:ok, :mystic}
  defp path(_other), do: :invalid
end
