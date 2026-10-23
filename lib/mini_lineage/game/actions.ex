defmodule MiniLineage.Game.Actions do
  @moduledoc """
  Every state-changing action, as a function from a player to `{player, result}` — the shape
  `Characters.mutate/2` runs inside the character's process. Each declares its own preconditions:
  client-side routing is convenience, these guards are the boundary.
  """
  alias MiniLineage.Game.{
    Constants,
    Format,
    Hunt,
    Math,
    Narrative,
    Narratives,
    Player,
    Rules,
    Shop
  }

  alias MiniLineage.Game.Version

  @errors %{
    already_started: "You already have a character.",
    invalid: "That is not something you can do.",
    closed: "The Gatekeeper cannot send you there yet.",
    last_level: "There is no level past the last.",
    no_ground: "There is nothing to hunt here.",
    no_shop: "There is no shop here.",
    unsold: "The shop does not sell that.",
    full: "You cannot carry any more, so sell or destroy something first.",
    not_carried: "You do not carry that.",
    equipped: "Take it off before you sell it.",
    worthless: "The shop will not buy that.",
    equipped_destroy: "Unequip it before you destroy it.",
    no_trainer: "Only the trainers of your own village teach you.",
    no_lesson: "The trainer does not teach that.",
    too_soon: "You are not yet ready to learn that.",
    out_of_order: "You must learn the level before it first.",
    no_sp: "You do not have enough SP to learn this skill.",
    not_wearable: "That is not something you can equip.",
    not_potion: "That is not something you drink.",
    whole: "You are already in full health.",
    no_share: "That is not a share you can choose.",
    no_heal: "You know no skill that mends, so there is nothing to order.",
    no_switch: "You cannot give that order for that skill.",
    fallen: "Your road has ended, and a ghost changes nothing.",
    living: "Only a run that has ended begins again."
  }

  # Not rules of the game: what a debug build hands over so the Gatekeeper and the trainer can be tried.
  @dev_adena 10_000
  @dev_sp 10_000

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
  def travel(%{dead: true} = player, _to), do: fallen(player)

  def travel(player, to) do
    route = Player.started?(player) && Rules.route(player.location, to)

    cond do
      !route -> {player, {:error, :invalid, @errors.invalid}}
      !Rules.town(to).open? -> {player, {:error, :closed, @errors.closed}}
      player.adena < route.fee -> {player, {:error, :poor, poor(player.location, route.fee)}}
      true -> arrive(player, Rules.town(to), route.fee)
    end
  end

  defp poor(from, fee),
    do: "#{Rules.town(from).gatekeeper} will not send you on for less than #{Format.adena(fee)}."

  defp arrive(player, town, fee) do
    gatekeeper = Rules.town(player.location).gatekeeper
    player = %{player | location: town.slug, adena: player.adena - fee}
    text = Narrative.alert(Narrative.build_arrived(gatekeeper, town, fee))
    {player, {:ok, %{text: text, type: :success}}}
  end

  @doc "Rules §20: back to town from the ground, disengaging on the way."
  def retreat(%{dead: true} = player), do: fallen(player)

  def retreat(player) do
    if Player.started?(player) and Rules.ground_of(player.location) do
      town = Rules.town(player.location)

      text =
        "You withdraw from the #{Rules.ground_of(player.location).name} to #{town.emoji} #{town.name}."

      {Player.disengage(player), {:ok, %{text: text, type: :info}}}
    else
      {player, {:error, :no_ground, @errors.no_ground}}
    end
  end

  @doc """
  Rules §20: one click, one fight, on the ground of the village the character stands in. A kill
  pays EXP, SP and Adena; a death (§21) leaves the run fallen there until it begins again.
  """
  def hunt(%{dead: true} = player), do: fallen(player)

  def hunt(player) do
    ground = Player.started?(player) && Rules.ground_of(player.location)

    if ground, do: fight(player, ground), else: {player, {:error, :no_ground, @errors.no_ground}}
  end

  defp fight(player, ground) do
    level = Player.level(player)
    foe = ground |> Rules.monsters_of() |> Hunt.draw(level) |> Hunt.foe()
    stats = Map.put(Player.stats(player), :auras, Player.buffs_up(player))
    bars = %{health: player.health, mp: player.mp}

    bars =
      Map.merge(bars, %{
        potions: Player.potions(player),
        potion_at: player.potion_at,
        heal_pull_at: player.heal_pull_at,
        path: player.path,
        heal_fight_at: player.heal_fight_at
      })

    result = Hunt.fight(stats, bars, Player.fighting_skills(player), foe)
    player = Player.put_buffs(%{player | health: result.health, mp: result.mp}, result.raised)
    player = Player.drink_down(player, result.drunk)
    stats = Player.stats(player)

    weapon = %{
      max_hp: stats.max_hp,
      bow?: stats.weapon != nil and stats.weapon.type == "bow",
      hp: bars.health
    }

    log =
      foe
      |> Narrative.build_fight_log(
        ground,
        result.log,
        weapon,
        result.before
      )
      |> Enum.map(&%{&1 | standing: Narrative.alert(&1.standing), line: Narrative.alert(&1.line)})

    {player, {:ok, flash}} =
      cond do
        result.health <= 0 ->
          fell = Narrative.alert(Narrative.build_fell(foe, ground))
          {die(player, foe, ground), {:ok, %{text: fell, type: :danger, sound: "death"}}}

        result.foe > 0 ->
          wandered = Narrative.alert(Narrative.build_wandered(foe, ground))
          {player, {:ok, %{text: wandered, type: :info}}}

        true ->
          reward(player, foe, ground, level)
      end

    # Rules §20: a hunt engages; only leaving the ground starts the disengaging.
    player = Player.engage(player)
    # The fight's length, which nothing draws, so the ladder bench can move its clock by it.
    flash = Map.merge(flash, %{log: log, ms: result.ms, outcome: outcome(player, result)})
    {%{player | encounter: encounter(flash, foe, ground)}, {:ok, flash}}
  end

  # Rules §21: the run is over where it fell, both bars empty and every aura gone with it, its end
  # told in a line drawn now and kept. The last draw of the run, so no die after it moves.
  defp die(player, foe, ground),
    do: %{
      player
      | dead: true,
        health: 0,
        mp: 0,
        killer: foe.name,
        fell_at: ground.slug,
        death_line: Math.random_element(Narratives.death()),
        buffs: %{},
        combat: nil
    }

  defp outcome(%{dead: true}, _result), do: :defeat
  defp outcome(_player, %{foe: foe}) when foe > 0, do: :escaped
  defp outcome(_player, _result), do: :victory

  # What `encounters` keeps of a fight: the page's log and what it came to, by its ground.
  defp encounter(flash, foe, ground),
    do:
      flash
      |> Map.take([:log, :text, :outcome, :levelled, :ms])
      |> Map.merge(%{ground: ground.slug, monster: foe.name})

  defp reward(player, foe, ground, level) do
    exp = Hunt.reward(foe.exp, Rules.rate(:exp), level, foe.level)
    sp = Hunt.reward(foe.sp, Rules.rate(:sp), level, foe.level)
    adena = Hunt.adena(foe, Rules.rate(:adena))

    gained = %{
      Player.gain_experience(player, exp)
      | sp: player.sp + sp,
        adena: player.adena + adena
    }

    reached = Player.level(gained)
    slew = Narrative.alert(Narrative.build_slew(foe, ground, exp, sp, adena))

    # A new level is the gold alert's to tell, so the kill's own line stops at what it paid.
    flash =
      if reached > level,
        do: %{text: slew, levelled: Narrative.alert(Narrative.build_congratulated(reached))},
        else: %{text: slew}

    {gained, {:ok, Map.put(flash, :type, :success)}}
  end

  @doc """
  Rules §24: buys an item from the shop of the village the character stands in; a potion (§26)
  `count` at a time, onto the stack it already carries.
  """
  def buy(player, name, count \\ 1)
  def buy(%{dead: true} = player, _name, _count), do: fallen(player)

  def buy(player, name, count) do
    item = Player.started?(player) && Rules.item?(name) && Rules.item(name)
    stack = item && Rules.stacks?(item) && Enum.find(player.items, &(&1.name == name))

    cond do
      !Player.started?(player) or !Rules.village?(player.location) ->
        {player, {:error, :no_shop, @errors.no_shop}}

      !item or !Shop.stocks?(player, item) or count < 1 or
          (count > 1 and !Rules.stacks?(item)) ->
        {player, {:error, :unsold, @errors.unsold}}

      player.adena < Shop.price(item) * count ->
        {player,
         {:error, :cannot_afford,
          "You cannot afford #{bought(item, count)} for #{Format.adena(Shop.price(item) * count)}."}}

      !stack and length(player.items) >= Rules.capacity() ->
        {player, {:error, :full, @errors.full}}

      true ->
        cost = Shop.price(item) * count

        items =
          if stack,
            do:
              Enum.map(
                player.items,
                &if(&1 == stack, do: %{&1 | count: &1.count + count}, else: &1)
              ),
            else: player.items ++ [Player.new_item(name, false, count)]

        text = "You buy #{bought(item, count)} for #{Format.adena(cost)}."

        {%{player | adena: player.adena - cost, items: items},
         {:ok, %{text: text, type: :success}}}
    end
  end

  defp bought(item, count),
    do: if(Rules.stacks?(item), do: "#{count} × #{item.name}", else: "the #{item.name}")

  @doc "Rules §24: sells something carried, not equipped, back to the village's shop for half its price."
  def sell(%{dead: true} = player, _id), do: fallen(player)

  def sell(player, id) do
    entry = Player.started?(player) && Enum.find(player.items, &(&1.id == id))

    cond do
      !Player.started?(player) or !Rules.village?(player.location) ->
        {player, {:error, :no_shop, @errors.no_shop}}

      !entry ->
        {player, {:error, :not_carried, @errors.not_carried}}

      entry.equipped ->
        {player, {:error, :equipped, @errors.equipped}}

      Shop.buyback(Rules.item(entry.name)) == 0 ->
        {player, {:error, :worthless, @errors.worthless}}

      true ->
        count = Map.get(entry, :count, 1)
        paid = Shop.buyback(Rules.item(entry.name)) * count
        player = %{player | adena: player.adena + paid, items: List.delete(player.items, entry)}
        what = if count > 1, do: "#{count} × #{entry.name}", else: "the #{entry.name}"

        text = "You sell #{what} for #{Format.adena(paid)}."

        {player, {:ok, %{text: text, type: :success}}}
    end
  end

  @doc "Rules §23: equips something carried, unequipping whatever it displaces."
  def equip(%{dead: true} = player, _id), do: fallen(player)

  def equip(player, id) do
    entry = Player.started?(player) && Enum.find(player.items, &(&1.id == id))

    if entry && Rules.stacks?(Rules.item(entry.name)) do
      {player, {:error, :not_wearable, @errors.not_wearable}}
    else
      wear(player, entry, id)
    end
  end

  defp wear(player, entry, id) do
    if entry do
      player = clamp_bars(%{player | items: Shop.put_on(player.items, id)})
      item = Rules.item(entry.name)

      # Rules §23: a weapon none of the character's weapon skills can be used with is equipped,
      # and said so.
      case item.kind == :weapon && unsuited(player, item) do
        [skill] ->
          text =
            "You equip the #{entry.name}, but your #{skill} skill needs #{Narrative.weapon_for(skill)}, so you will fight without it."

          {player, {:ok, %{text: text, type: :danger}}}

        [_, _ | _] = skills ->
          text =
            "You equip the #{entry.name}, but your #{Format.list(skills, "and")} skills cannot be used with #{Narrative.weapon(item.type)}, so you will fight without them."

          {player, {:ok, %{text: text, type: :danger}}}

        _fits ->
          {player, {:ok, %{text: "You equip the #{entry.name}.", type: :info}}}
      end
    else
      {player, {:error, :not_carried, @errors.not_carried}}
    end
  end

  @doc "Rules §26: drinks one potion carried, in town or anywhere, healing at once."
  def drink(%{dead: true} = player, _id), do: fallen(player)

  def drink(player, id) do
    entry = Player.started?(player) && Enum.find(player.items, &(&1.id == id))
    item = entry && Rules.item(entry.name)
    max_hp = Player.started?(player) && Player.stats(player).max_hp

    cond do
      !entry ->
        {player, {:error, :not_carried, @errors.not_carried}}

      !Rules.stacks?(item) ->
        {player, {:error, :not_potion, @errors.not_potion}}

      player.health >= max_hp ->
        {player, {:error, :whole, @errors.whole}}

      true ->
        healed = min(item.heals, max_hp - player.health)
        player = Player.drink_down(%{player | health: player.health + healed}, %{entry.name => 1})

        text =
          ~s(You drink a #{entry.name} and mend <span class="regen">#{healed} HP</span>.)

        {player, {:ok, %{text: text, type: :success}}}
    end
  end

  # The orders below succeed with nothing to say: each is a setting its own control shows.

  @doc "Rules §26: the share of HP below which the character drinks a potion in a fight."
  def potion_at(%{dead: true} = player, _share), do: fallen(player)

  def potion_at(player, share) do
    if Player.started?(player) and share in Player.potion_shares() do
      {%{player | potion_at: share}, {:ok, nil}}
    else
      {player, {:error, :no_share, @errors.no_share}}
    end
  end

  @doc "Rules §20: the share of HP below which the character heals, before a pull or in a fight."
  def heal_at(%{dead: true} = player, _moment, _share), do: fallen(player)

  def heal_at(player, moment, share) when moment in [:pull, :fight] do
    cond do
      not Player.started?(player) or share not in Player.heal_shares() ->
        {player, {:error, :no_share, @errors.no_share}}

      not Player.heals?(player) ->
        {player, {:error, :no_heal, @errors.no_heal}}

      true ->
        key = if moment == :pull, do: :heal_pull_at, else: :heal_fight_at
        {Map.put(player, key, share), {:ok, nil}}
    end
  end

  @doc "Rules §20: whether the character uses a skill it knows in a fight, or leaves it unused."
  def use_skill(%{dead: true} = player, _name, _use?), do: fallen(player)

  def use_skill(player, name, use?) when is_boolean(use?) do
    if Player.started?(player) and name in Player.switchable(player) do
      unused = player.unused |> List.delete(name) |> then(&if(use?, do: &1, else: [name | &1]))
      {%{player | unused: Enum.sort(unused)}, {:ok, nil}}
    else
      {player, {:error, :no_switch, @errors.no_switch}}
    end
  end

  @doc "Rules §20 and §26: every order back to the one a new character starts with."
  def reset_orders(%{dead: true} = player), do: fallen(player)

  def reset_orders(player) do
    if Player.started?(player) do
      {Map.merge(player, Player.default_orders()), {:ok, nil}}
    else
      {player, {:error, :invalid, @errors.invalid}}
    end
  end

  # The weapon skills it knows, if not one of them can be used with this weapon.
  defp unsuited(player, item) do
    names = for {name, _} <- player.skills, Rules.weapon_skill?(name), do: name
    if Enum.any?(names, &Rules.skill_weapon?(&1, item)), do: [], else: Enum.sort(names)
  end

  @doc "Rules §23: unequips something equipped, which stays carried."
  def unequip(%{dead: true} = player, _id), do: fallen(player)

  def unequip(player, id) do
    entry = Player.started?(player) && Enum.find(player.items, &(&1.id == id))

    if entry do
      items = Enum.map(player.items, &if(&1.id == id, do: %{&1 | equipped: false}, else: &1))
      player = clamp_bars(%{player | items: items})
      {player, {:ok, %{text: "You unequip the #{entry.name}.", type: :info}}}
    else
      {player, {:error, :not_carried, @errors.not_carried}}
    end
  end

  @doc """
  Rules §25: learns one line from the trainer of the character's own village, once it has reached
  the line's level, knows the level before it, and has the SP.
  """
  def learn(%{dead: true} = player, _skill, _level), do: fallen(player)

  def learn(player, skill, level) do
    set = Player.started?(player) && Rules.set(player.race_id, player.path).name
    lesson = set && Enum.find(Rules.lessons(set), &(&1.skill == skill and &1.level == level))

    cond do
      !set or player.location != Rules.hometown(player.race_id) ->
        {player, {:error, :no_trainer, @errors.no_trainer}}

      !lesson ->
        {player, {:error, :no_lesson, @errors.no_lesson}}

      Player.level(player) < lesson.learn_at ->
        {player, {:error, :too_soon, @errors.too_soon}}

      Map.get(player.skills, skill, 0) != level - 1 ->
        {player, {:error, :out_of_order, @errors.out_of_order}}

      player.sp < lesson.sp ->
        {player, {:error, :no_sp, @errors.no_sp}}

      true ->
        player = %{
          player
          | sp: player.sp - lesson.sp,
            skills: Map.put(player.skills, skill, level)
        }

        text =
          ~s(You learn <span class="skill">#{skill} #{level}</span> for <span class="sp">#{Format.number(lesson.sp)} SP</span>.)

        {clamp_bars(player), {:ok, %{text: text, type: :success}}}
    end
  end

  @doc "Rules §23: destroys something carried and not equipped, for good."
  def destroy(%{dead: true} = player, _id), do: fallen(player)

  def destroy(player, id) do
    entry = Player.started?(player) && Enum.find(player.items, &(&1.id == id))

    cond do
      !entry ->
        {player, {:error, :not_carried, @errors.not_carried}}

      entry.equipped ->
        {player, {:error, :equipped_destroy, @errors.equipped_destroy}}

      true ->
        {%{player | items: List.delete(player.items, entry)},
         {:ok, %{text: "You destroy the #{entry.name}.", type: :info}}}
    end
  end

  @doc """
  Rules §21: a run that has ended begins again, which leaves it to the Monument and the browser to
  game start; its process retires it on seeing a fallen run come back unstarted.
  """
  def restart(%{dead: true}), do: {%Player{}, {:ok, %{}}}
  def restart(player), do: {player, {:error, :living, @errors.living}}

  defp fallen(player), do: {player, {:error, :fallen, @errors.fallen}}

  # A robe taken off lowers Max MP (§23), and MP never stands above it.
  defp clamp_bars(player), do: %{player | mp: min(player.mp, Player.stats(player).max_mp)}

  @doc "Debug builds only: Adena to try the Gatekeeper with, every time it is asked for."
  def dev_adena(%{dead: true} = player), do: fallen(player)

  def dev_adena(player) do
    if Version.debug_build?() and Player.started?(player) do
      text =
        "A debug build drops #{Format.adena(@dev_adena)} into your purse."

      {%{player | adena: player.adena + @dev_adena}, {:ok, %{text: text, type: :info}}}
    else
      {player, {:error, :invalid, @errors.invalid}}
    end
  end

  @doc "Debug builds only: SP to try the trainer with, every time it is asked for."
  def dev_sp(%{dead: true} = player), do: fallen(player)

  def dev_sp(player) do
    if Version.debug_build?() and Player.started?(player) do
      text =
        ~s(A debug build hands you <span class="sp">#{Format.number(@dev_sp)} SP</span> to learn with.)

      {%{player | sp: player.sp + @dev_sp}, {:ok, %{text: text, type: :info}}}
    else
      {player, {:error, :invalid, @errors.invalid}}
    end
  end

  @doc "Debug builds only: both bars to half, and the XP bar halfway to the next level."
  def dev_half(%{dead: true} = player), do: fallen(player)

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

  @doc "Debug builds only: 1 HP, so the next fight on the ground can end the run."
  def dev_frail(%{dead: true} = player), do: fallen(player)

  def dev_frail(player) do
    if Version.debug_build?() and Player.started?(player) do
      text = ~s(A debug build leaves you <span class="hp">1 HP</span> to hunt with.)
      {%{player | health: 1}, {:ok, %{text: text, type: :info}}}
    else
      {player, {:error, :invalid, @errors.invalid}}
    end
  end

  @doc "Debug builds only: exactly the EXP the next level needs, which refills both bars."
  def dev_level(player), do: dev_reach(player, Player.level(player) + 1)

  @doc "Debug builds only: exactly the EXP the last level needs, which refills both bars."
  def dev_max_level(player), do: dev_reach(player, Rules.max_level())

  defp dev_reach(%{dead: true} = player, _target), do: fallen(player)

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

        flash = %{
          text: text,
          type: :info,
          levelled: Narrative.alert(Narrative.build_congratulated(target))
        }

        {Player.gain_experience(player, needed), {:ok, flash}}
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
