defmodule MiniLineage.Game.MessagesTest do
  @moduledoc """
  docs/canon/messages.md's table read back against `Actions`: every refusal a player can meet says
  what the table says, every other guard says `invalid`, and every success reads as its template
  filled in. Pure.
  """
  use ExUnit.Case, async: true

  alias MiniLineage.Game.{Actions, Clock, Constants, Format, Math, Names, Player, Rules, Shop}

  @doc_table File.read!("docs/canon/messages.md")

  setup do
    Clock.put_now(~U[2026-07-01 09:00:00Z])
    :ok
  end

  # The "What the game says" table, as %{key => {id, text}}.
  defp rows do
    [_, body] = String.split(@doc_table, "| Key | Id | Says |", parts: 2)

    body
    |> String.split("\n")
    |> Enum.drop(2)
    |> Enum.take_while(&String.starts_with?(&1, "|"))
    |> Map.new(fn row ->
      [key, id, text] = row |> String.split("|", trim: true) |> Enum.map(&String.trim/1)
      {key |> String.trim("`") |> String.to_existing_atom(), {id, text}}
    end)
  end

  defp says(key), do: rows() |> Map.fetch!(key) |> elem(1)

  defp fill(key, values),
    do:
      Enum.reduce(values, says(key), fn {slot, value}, text ->
        String.replace(text, slot, value)
      end)

  defp fighter(adena \\ 100_000) do
    {player, _} = Player.initialize(%Player{}, Constants.race(0), :fighter, "Herald")
    %{player | adena: adena}
  end

  defp carried(player, name), do: Enum.find(player.items, &(&1.name == name))
  defp text({_player, {_, %{text: text}}}), do: text

  @successes ~w(learn equip unequip destroy buy sell drink)a

  # Each refusal the table lists, as the action that meets it.
  defp refusals do
    player = fighter()

    filler =
      for _ <- 1..(Rules.capacity() - length(player.items)), do: Player.new_item("Short Sword")

    full = %{player | items: player.items ++ filler}
    drinker = potion(player)

    %{
      invalid: Actions.reset_orders(%Player{}),
      already_started: Actions.start(fighter(), 0, "mystic", "Usurper"),
      last_level:
        Actions.dev_level(%{fighter() | experience: Math.xp_for_level(Rules.max_level())}),
      full: Actions.buy(full, "Broadsword"),
      cannot_afford: Actions.buy(fighter(100), "Broadsword"),
      poor: Actions.travel(fighter(0), "town-of-gludio"),
      no_sp:
        Actions.learn(%{fighter() | experience: Math.xp_for_level(5), sp: 0}, "Power Strike", 2),
      whole: Actions.drink(drinker, carried(drinker, "Lesser Healing Potion").id),
      fallen: Actions.hunt(%{fighter() | dead: true})
    }
  end

  defp potion(player),
    do: player |> Actions.buy("Lesser Healing Potion", 1) |> elem(0) |> Player.restore_fully()

  test "every refusal a player can meet says what the table says, and nothing else is listed" do
    listed = for {key, _} <- rows(), key not in @successes, do: key
    assert Enum.sort(listed) == Enum.sort(Map.keys(refusals()))

    for {code, {_player, result}} <- refusals() do
      assert {:error, ^code, text} = result
      assert text == says(code), inspect(code)
    end
  end

  test "a refusal the client has is its message, and the rest are ours" do
    for {key, {id, _}} <- rows() do
      assert id == "ours" or match?({_, ""}, Integer.parse(id)), inspect(key)
    end

    assert {"279", _} = rows().cannot_afford
    assert {"279", _} = rows().poor
    assert {"129", _} = rows().full
    assert {"278", _} = rows().no_sp
  end

  test "a guard no click reaches keeps its own code and says only that it cannot be done" do
    assert {_, {:error, :unsold, text}} = Actions.buy(fighter(), "Falchion")
    assert text == says(:invalid)

    player = fighter()
    sword = carried(player, "Squire's Sword")
    assert {_, {:error, :equipped_destroy, ^text}} = Actions.destroy(player, sword.id)
  end

  test "a refusal names neither the item nor its price" do
    assert {_, {:error, :cannot_afford, text}} = Actions.buy(fighter(100), "Broadsword")
    assert text == says(:cannot_afford)
    refute text =~ "Broadsword"
  end

  test "every success reads as its template filled in" do
    item = Rules.item("Broadsword")
    {player, _} = bought = Actions.buy(fighter(), "Broadsword")

    assert text(bought) ==
             fill(:buy, %{
               "$s1" => "the #{Names.item(item)}",
               "$adena" => Format.adena(Shop.price(item))
             })

    id = carried(player, "Broadsword").id
    {player, _} = equipped = Actions.equip(player, id)
    assert text(equipped) == fill(:equip, %{"$s1" => Names.item(item)})

    {player, _} = disarmed = Actions.unequip(player, id)
    assert text(disarmed) == fill(:unequip, %{"$s1" => Names.item(item)})

    assert text(Actions.sell(player, id)) ==
             fill(:sell, %{
               "$s1" => "the #{Names.item(item)}",
               "$adena" => Format.adena(Shop.buyback(item))
             })

    dagger = carried(player, "Squire's Dagger")

    assert text(Actions.destroy(player, dagger.id)) ==
             fill(:destroy, %{"$s1" => Names.item(dagger.name)})

    {player, _} = Actions.buy(player, "Lesser Healing Potion", 1)
    potion = carried(player, "Lesser Healing Potion")
    heals = Rules.item(potion.name).heals

    assert text(Actions.drink(%{player | health: 10}, potion.id)) ==
             fill(:drink, %{
               "$s1" => Names.item(potion.name),
               "$hp" => ~s(<span class="regen">#{heals} HP</span>)
             })

    pupil = %{player | experience: Math.xp_for_level(5), sp: 100}

    assert text(Actions.learn(pupil, "Power Strike", 2)) ==
             fill(:learn, %{"$s1" => Names.skill("Power Strike", 2), "$sp" => Format.sp(100)})
  end
end
