defmodule MiniLineage.Game.PotionsTest do
  @moduledoc """
  Rules §26: a potion bought by the lot onto one stack, drunk at once in town, and drunk by the
  character itself in a fight below the share its player chose. Pure but for pinned dice.
  """
  use ExUnit.Case, async: true

  alias MiniLineage.Characters.Serde
  alias MiniLineage.Game.{Actions, Clock, Constants, Hunt, Math, Names, Player, Rng, Rules}

  @potion "Lesser Healing Potion"

  setup do
    Clock.put_now(~U[2026-07-01 09:00:00Z])
    :ok
  end

  defp human(adena \\ 10_000) do
    {player, _} = Player.initialize(%Player{}, Constants.race(0), :fighter, "Drinker")
    Player.restore_fully(%{player | adena: adena, experience: Math.xp_for_level(10)})
  end

  defp stack(player), do: Enum.find(player.items, &(&1.name == @potion))

  test "a lot is bought onto one stack, one place in the inventory, at its price each" do
    player = human()
    {player, {:ok, _}} = Actions.buy(player, @potion, 10)
    {player, {:ok, _}} = Actions.buy(player, @potion, 50)

    assert stack(player).count == 60
    assert Enum.count(player.items, &(&1.name == @potion)) == 1
    assert player.adena == 10_000 - 60 * 90

    assert {_, {:error, :cannot_afford, _}} = Actions.buy(human(899), @potion, 10)
    assert {_, {:error, :unsold, _}} = Actions.buy(player, "Short Sword", 2)
  end

  test "a full inventory still takes more onto a stack it carries" do
    {player, {:ok, _}} = Actions.buy(human(), @potion, 1)

    filler =
      for _ <- 1..(Rules.capacity() - length(player.items)), do: Player.new_item("Short Sword")

    full = %{player | items: player.items ++ filler}

    assert {topped, {:ok, _}} = Actions.buy(full, @potion, 10)
    assert stack(topped).count == 11
  end

  test "a stack sells whole for half its price each, and is never put on" do
    {player, {:ok, _}} = Actions.buy(human(0) |> Map.put(:adena, 900), @potion, 10)
    id = stack(player).id

    assert {_, {:error, :not_wearable, _}} = Actions.equip(player, id)
    {sold, {:ok, _}} = Actions.sell(player, id)
    assert sold.adena == 450 and stack(sold) == nil
  end

  test "drunk in town it heals at once, takes one, and is refused at full HP" do
    {player, {:ok, _}} = Actions.buy(human(), @potion, 2)
    id = stack(player).id
    assert {_, {:error, :whole, _}} = Actions.drink(player, id)

    {drunk, {:ok, _}} = Actions.drink(%{player | health: 10}, id)
    assert drunk.health == 10 + 112 and stack(drunk).count == 1

    {last, {:ok, _}} = Actions.drink(%{drunk | health: 10}, id)
    assert stack(last) == nil
  end

  test "the share is one the rules offer, and is kept with the character" do
    {player, {:ok, _}} = Actions.potion_at(human(), 30)
    assert player.potion_at == 30
    assert {_, {:error, :no_share, _}} = Actions.potion_at(player, 40)

    stored = player |> Serde.to_map() |> Jason.encode!() |> Jason.decode!()
    assert Serde.from_map(stored).potion_at == 30
    assert Serde.from_map(Map.put(stored, "potion_at", 40)).potion_at == 50
  end

  describe "in a fight" do
    # A monster that never falls, so only what the character drinks moves its HP up.
    defp dummy, do: %{Hunt.foe(Rules.monster("Young Keltir")) | hp: 1_000_000_000}

    defp bars(player, share, count),
      do: %{
        health: player.health,
        mp: player.mp,
        potions: [%{name: @potion, heals: 112, count: count}],
        potion_at: share
      }

    test "below the share it drinks one a round until none are left" do
      Rng.put_source(fn -> 0.0 end)
      player = human()
      stats = Player.stats(player)
      low = %{player | health: div(stats.max_hp, 3)}
      result = Hunt.fight(stats, bars(low, 50, 3), [], dummy())

      drinks = for {round, {:potion, @potion, _, _}} <- result.log, do: round
      assert result.drunk == %{@potion => 3}
      assert hd(drinks) == 1 and drinks == Enum.uniq(drinks)
    end

    test "never at a share of 0, nor above the share" do
      Rng.put_source(fn -> 0.0 end)
      player = human()
      stats = Player.stats(player)

      assert Hunt.fight(stats, bars(%{player | health: 10}, 0, 3), [], dummy()).drunk == %{}
      whole = Hunt.fight(stats, bars(player, 50, 3), [], %{dummy() | hp: 1})
      assert whole.drunk == %{}
    end

    test "a hunt takes what was drunk off the stack" do
      Rng.put_source(fn -> 0.0 end)
      {player, {:ok, _}} = Actions.buy(human(), @potion, 5)
      low = %{player | health: 20}
      {hunted, {:ok, flash}} = Actions.hunt(low)

      drunk = Enum.count(flash.log, &(&1.line =~ "drink a #{Names.item(@potion)}"))
      assert drunk >= 1
      assert (stack(hunted) || %{count: 0}).count == 5 - drunk
    end
  end
end
