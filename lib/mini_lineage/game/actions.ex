defmodule MiniLineage.Game.Actions do
  @moduledoc """
  Every state-changing action, as a function from a player to `{player, result}` — the shape
  `Characters.mutate/2` runs inside the character's process. Each declares its own preconditions:
  client-side routing is convenience, these guards are the boundary.
  """
  alias MiniLineage.Game.{
    Clock,
    Constants,
    Format,
    Hunt,
    Math,
    Names,
    Narrative,
    Narratives,
    Player,
    Rules,
    Shop
  }

  alias MiniLineage.Game.Version

  # What a refusal a player can meet says, as docs/canon/messages.md lists it. Every other code is a
  # guard no click reaches (a list offers only what can be done) and says only `invalid`.
  @errors %{
    invalid: "That is not something you can do.",
    already_started: "You already have a character.",
    last_level: "There is no level past the last.",
    full: "Your inventory is full.",
    cannot_afford: "You do not have enough Adena.",
    poor: "You do not have enough Adena.",
    no_sp: "You do not have enough SP to learn this skill.",
    whole: "You are already at full health.",
    fallen: "Your road has ended, and a ghost changes nothing."
  }

  # Not rules of the game: what a debug build hands over so the Gatekeeper and the trainer can be tried.
  @dev_adena 10_000
  @dev_sp 10_000
  @dev_twink_level 15
  @dev_twink_potions {"Lesser Healing Potion", 30}
  @dev_twink_sp 10_000
  @dev_twink_adena 50_000

  @doc "Creates the character: a race, a path and a name, all checked here."
  def start(player, race_id, path, name) do
    cond do
      Player.started?(player) ->
        refuse(player, :already_started)

      true ->
        case validate_start(race_id, path, name) do
          :invalid -> refuse(player, :invalid)
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
      !route -> refuse(player, :invalid)
      !Rules.town(to).open? -> refuse(player, :closed)
      player.adena < route.fee -> refuse(player, :poor)
      true -> arrive(player, Rules.town(to), route.fee)
    end
  end

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
      refuse(player, :no_ground)
    end
  end

  @doc """
  Rules §20: one click, one fight, on the ground of the village the character stands in. A kill
  pays EXP, SP and Adena; a death (§21) leaves the run fallen there until it begins again.
  """
  def hunt(%{dead: true} = player), do: fallen(player)

  def hunt(player) do
    ground = Player.started?(player) && Rules.ground_of(player.location)

    if ground, do: fight(player, ground), else: refuse(player, :no_ground)
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
      weapon: stats.weapon,
      shield: stats.shield,
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
    player = %{player | fought: player.fought + 1}
    # The fight's length, which nothing draws, so the ladder bench can move its clock by it.
    flash = Map.merge(flash, %{log: log, ms: result.ms, outcome: outcome(player, result)})
    {%{player | encounter: encounter(flash, foe, ground)}, {:ok, flash}}
  end

  # Rules §21: the run is over where it fell, both bars empty and every aura gone with it.
  defp die(player, foe, ground),
    do: %{
      player
      | dead: true,
        health: 0,
        mp: 0,
        killer: foe.name,
        fell_at: ground.slug,
        died_at: DateTime.to_unix(Clock.now(), :millisecond),
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
        do: %{text: slew, levelled: Narrative.alert(Narratives.levelled())},
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
        refuse(player, :no_shop)

      !item or !Shop.stocks?(player, item) or count < 1 or
          (count > 1 and !Rules.stacks?(item)) ->
        refuse(player, :unsold)

      player.adena < Shop.price(item) * count ->
        refuse(player, :cannot_afford)

      !stack and length(player.items) >= Rules.capacity() ->
        refuse(player, :full)

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
    do:
      if(Rules.stacks?(item),
        do: "#{count} × #{Names.item(item)}",
        else: "the #{Names.item(item)}"
      )

  @doc "Rules §24: sells something carried, not equipped, back to the village's shop for half its price."
  def sell(%{dead: true} = player, _id), do: fallen(player)

  def sell(player, id) do
    entry = Player.started?(player) && Enum.find(player.items, &(&1.id == id))

    cond do
      !Player.started?(player) or !Rules.village?(player.location) ->
        refuse(player, :no_shop)

      !entry ->
        refuse(player, :not_carried)

      entry.equipped ->
        refuse(player, :equipped)

      Shop.buyback(Rules.item(entry.name)) == 0 ->
        refuse(player, :worthless)

      true ->
        count = Map.get(entry, :count, 1)
        paid = Shop.buyback(Rules.item(entry.name)) * count
        player = %{player | adena: player.adena + paid, items: List.delete(player.items, entry)}

        what =
          if count > 1,
            do: "#{count} × #{Names.item(entry.name)}",
            else: "the #{Names.item(entry.name)}"

        text = "You sell #{what} for #{Format.adena(paid)}."

        {player, {:ok, %{text: text, type: :success}}}
    end
  end

  @doc "Rules §23: equips something carried, unequipping whatever it displaces."
  def equip(%{dead: true} = player, _id), do: fallen(player)

  def equip(player, id) do
    entry = Player.started?(player) && Enum.find(player.items, &(&1.id == id))

    if entry && Rules.stacks?(Rules.item(entry.name)) do
      refuse(player, :not_wearable)
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
            "You have equipped your #{Names.item(item)}, but your #{Names.skill(skill)} skill needs #{Narrative.weapon_for(skill)}, so you will fight without it."

          {player, {:ok, %{text: text, type: :danger}}}

        [_, _ | _] = skills ->
          text =
            "You have equipped your #{Names.item(item)}, but your #{Format.list(Enum.map(skills, &Names.skill/1), "and")} skills cannot be used with #{Narrative.weapon(item.type)}, so you will fight without them."

          {player, {:ok, %{text: text, type: :danger}}}

        _fits ->
          {player, {:ok, %{text: "You have equipped your #{Names.item(item)}.", type: :info}}}
      end
    else
      refuse(player, :not_carried)
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
        refuse(player, :not_carried)

      !Rules.stacks?(item) ->
        refuse(player, :not_potion)

      player.health >= max_hp ->
        refuse(player, :whole)

      true ->
        healed = min(item.heals, max_hp - player.health)
        player = Player.drink_down(%{player | health: player.health + healed}, %{entry.name => 1})

        text =
          ~s(You drink a #{Names.item(item)} and mend <span class="regen">#{healed} HP</span>.)

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
      refuse(player, :no_share)
    end
  end

  @doc "Rules §20: the share of HP below which the character heals, before a pull or in a fight."
  def heal_at(%{dead: true} = player, _moment, _share), do: fallen(player)

  def heal_at(player, moment, share) when moment in [:pull, :fight] do
    cond do
      not Player.started?(player) or share not in Player.heal_shares() ->
        refuse(player, :no_share)

      not Player.heals?(player) ->
        refuse(player, :no_heal)

      not Player.heals_in_use?(player) ->
        refuse(player, :heal_unused)

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
      refuse(player, :no_switch)
    end
  end

  @doc "Rules §20 and §26: every order back to the one a new character starts with."
  def reset_orders(%{dead: true} = player), do: fallen(player)

  def reset_orders(player) do
    if Player.started?(player) do
      {Map.merge(player, Player.default_orders()), {:ok, nil}}
    else
      refuse(player, :invalid)
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
      {player, {:ok, %{text: "#{Names.item(entry.name)} has been disarmed.", type: :info}}}
    else
      refuse(player, :not_carried)
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
        refuse(player, :no_trainer)

      !lesson ->
        refuse(player, :no_lesson)

      Player.level(player) < lesson.learn_at ->
        refuse(player, :too_soon)

      Map.get(player.skills, skill, 0) != level - 1 ->
        refuse(player, :out_of_order)

      player.sp < lesson.sp ->
        refuse(player, :no_sp)

      true ->
        player = %{
          player
          | sp: player.sp - lesson.sp,
            skills: Map.put(player.skills, skill, level)
        }

        text =
          "You have earned #{Names.skill(skill, level)} for #{Format.sp(lesson.sp)}."

        {clamp_bars(player), {:ok, %{text: text, type: :success}}}
    end
  end

  @doc "Rules §23: destroys something carried and not equipped, for good."
  def destroy(%{dead: true} = player, _id), do: fallen(player)

  def destroy(player, id) do
    entry = Player.started?(player) && Enum.find(player.items, &(&1.id == id))

    cond do
      !entry ->
        refuse(player, :not_carried)

      entry.equipped ->
        refuse(player, :equipped_destroy)

      true ->
        {%{player | items: List.delete(player.items, entry)},
         {:ok, %{text: "#{Names.item(entry.name)} has disappeared.", type: :info}}}
    end
  end

  @doc """
  Rules §21: a run that has ended begins again, which leaves it to the Monument and the browser to
  game start; its process retires it on seeing a fallen run come back unstarted.
  """
  def restart(%{dead: true}), do: {%Player{}, {:ok, %{}}}
  def restart(player), do: refuse(player, :living)

  defp fallen(player), do: refuse(player, :fallen)

  defp refuse(player, code), do: {player, {:error, code, Map.get(@errors, code, @errors.invalid)}}

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
      refuse(player, :invalid)
    end
  end

  @doc "Debug builds only: SP to try the trainer with, every time it is asked for."
  def dev_sp(%{dead: true} = player), do: fallen(player)

  def dev_sp(player) do
    if Version.debug_build?() and Player.started?(player) do
      text =
        "A debug build hands you #{Format.sp(@dev_sp)} to learn with."

      {%{player | sp: player.sp + @dev_sp}, {:ok, %{text: text, type: :info}}}
    else
      refuse(player, :invalid)
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
      refuse(player, :invalid)
    end
  end

  @doc "Debug builds only: 1 HP, so the next fight on the ground can end the run."
  def dev_frail(%{dead: true} = player), do: fallen(player)

  def dev_frail(player) do
    if Version.debug_build?() and Player.started?(player) do
      text = ~s(A debug build leaves you <span class="hp">1 HP</span> to hunt with.)
      {%{player | health: 1}, {:ok, %{text: text, type: :info}}}
    else
      refuse(player, :invalid)
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
        refuse(player, :invalid)

      Math.max_level?(Player.level(player)) ->
        refuse(player, :last_level)

      true ->
        needed = Math.xp_for_level(target) - player.experience

        text =
          ~s(A debug build hands you <span class="xp">#{Format.number(needed)} XP</span>, enough to reach <span class="level">Level #{target}</span>.)

        flash = %{
          text: text,
          type: :info,
          levelled: Narrative.alert(Narratives.levelled())
        }

        {Player.gain_experience(player, needed), {:ok, flash}}
    end
  end

  @doc """
  Debug builds only: the run put back to one saved state however often it is typed, Level 15 with
  every lesson its trainer teaches by then, the best of every line its village's traders sell its
  set, the kit's own line equipped (with the shield beside a one-handed weapon), potions, SP and
  Adena, the default orders with every skill in use, and both bars full under the new gear.
  """
  def dev_twink(%{dead: true} = player), do: fallen(player)

  def dev_twink(player) do
    if Version.debug_build?() and Player.started?(player) do
      level = Player.level(player)
      {potion, count} = @dev_twink_potions

      twinked =
        Player.restore_fully(%{
          Map.merge(player, Player.default_orders())
          | experience: Math.xp_for_level(@dev_twink_level),
            skills: twink_skills(player),
            items: twink_items(player),
            sp: @dev_twink_sp,
            adena: @dev_twink_adena
        })

      text =
        ~s(A debug build puts you back at <span class="level">Level #{@dev_twink_level}</span> with every skill your trainer teaches by then, the best your village sells, #{count} × #{Names.item(potion)}, #{Format.sp(@dev_twink_sp)} and #{Format.adena(@dev_twink_adena)}.)

      flash =
        if @dev_twink_level > level,
          do: %{
            text: text,
            type: :info,
            levelled: Narrative.alert(Narratives.levelled())
          },
          else: %{text: text, type: :info}

      {twinked, {:ok, flash}}
    else
      refuse(player, :invalid)
    end
  end

  # Each skill at the last level its trainer teaches by the twink's level.
  defp twink_skills(player) do
    for lesson <- Rules.lessons(Rules.set(player.race_id, player.path).name),
        lesson.learn_at <= @dev_twink_level,
        reduce: %{} do
      skills -> Map.update(skills, lesson.skill, lesson.level, &max(&1, lesson.level))
    end
  end

  # What it already carries of the set is kept under its own id, so typing it again writes only
  # what was sold, destroyed or bought since.
  defp twink_items(player) do
    {potion, count} = @dev_twink_potions

    {items, _left} =
      Enum.map_reduce(twink_gear(player) ++ [{potion, false, count}], player.items, fn
        {name, worn, count}, left ->
          case Enum.find(left, &(&1.name == name)) do
            nil -> {Player.new_item(name, worn, count), left}
            entry -> {%{entry | equipped: worn, count: count}, List.delete(left, entry)}
          end
      end)

    items
  end

  # One item per line (a slot, a type and the hands it takes, so a one-handed sword and a
  # two-handed one are both kept), the dearest of each, as {name, equipped, count}.
  defp twink_gear(player) do
    set = Rules.set(player.race_id, player.path)
    {kit, _carried} = Rules.kit(player.race_id, player.path)
    kit_weapon = kit |> Enum.map(&Rules.item/1) |> Enum.find(&(&1.slot == :weapon))

    best =
      set.race_id
      |> Rules.hometown()
      |> Rules.stock(set)
      |> Enum.reject(&Rules.stacks?/1)
      |> Enum.sort_by(&Shop.price/1, :desc)
      |> Enum.uniq_by(&{&1.slot, &1.type, &1.hands})

    weapons = Enum.filter(best, &(&1.slot == :weapon))
    wielded = Enum.find(weapons, &(&1.type == kit_weapon.type and &1.hands == kit_weapon.hands))
    one_handed? = Enum.any?(weapons, &(&1.hands == 1))

    for item <- best, item.slot != :shield or one_handed? do
      worn =
        case item.slot do
          :weapon -> item == wielded
          :shield -> wielded.hands == 1
          _armour_or_necklace -> true
        end

      {item.name, worn, 1}
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
