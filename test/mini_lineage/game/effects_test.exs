defmodule MiniLineage.Game.EffectsTest do
  @moduledoc """
  What happens when one effect meets another.

  A meal's buff belongs to a group, and a second meal replaces the first rather than stacking — a
  player who could hold three food buffs at once would carry three times the health the balance was
  built around. The Hexed debuff has no group and so is its own case.
  """
  use ExUnit.Case, async: true

  alias MiniLineage.Game.{Constants, Narrative, Player}

  defp fed(player, food_id) do
    {player, _} = Player.purchase(player, "food", food_id)
    player
  end

  defp hero do
    {player, _} = Player.initialize(%Player{}, Constants.race(1), "Hero")
    %{player | adena: 100_000, health: 1}
  end

  defp food_buffs(player), do: Enum.filter(player.effects, &(&1.group == "food"))

  describe "a meal's buff" do
    test "replaces the one before it rather than stacking" do
      # Hearty Mash then Roasted Pheasant: the top three dishes each grant a timed buff.
      player = hero() |> fed(3) |> fed(4)

      assert length(food_buffs(player)) == 1
      assert hd(food_buffs(player)).id == "gourmet_feast"
    end

    test "and replacing it does not multiply the health it grants" do
      one = hero() |> fed(3)
      two = hero() |> fed(3) |> fed(4)

      assert Player.stats(two).max_health < Player.stats(one).max_health * 2
    end

    test "even when the same dish is eaten twice" do
      player = hero() |> fed(3) |> fed(3)

      assert length(food_buffs(player)) == 1
    end

    test "while the cheapest dishes grant none at all, only health" do
      player = hero() |> fed(0)

      assert food_buffs(player) == []
    end
  end

  describe "an effect with no group" do
    test "sits alongside a food buff rather than replacing it" do
      hexed = Constants.effects().ambush_debuff
      player = hero() |> fed(4) |> Player.apply_effect(hexed)

      assert length(food_buffs(player)) == 1
      assert Enum.any?(player.effects, &(&1.id == hexed.id))
    end
  end

  # The chronicle says effects leave in the order they arrived. A refresh brings no new line, so it
  # must not move the effect either, or one re-eaten meal would reorder the departures.
  describe "the order effects are held in" do
    test "is the order they arrived, and a refresh keeps its place" do
      hexed = Constants.effect(:ambush_debuff)
      player = hero() |> fed(2) |> Player.apply_effect(hexed) |> fed(2)

      assert Enum.map(player.effects, & &1.id) |> Enum.reject(&(&1 in ~w(resting combat))) ==
               ["newbie_blessing", "satisfied", "hexed"]
    end
  end

  # A deed is written once: the chronicle keeps it with its pronouns open, and the alert is the same
  # sentence told to its owner. Two texts written in two places had drifted into saying different
  # things, the alert "You have bought" and the chronicle "They ate".
  describe "an alert and the chronicle" do
    test "say the same thing about a meal, the buff it brought included" do
      {fed, result} = Player.purchase(%{hero() | health: 50}, "food", 2)
      [bought] = Enum.filter(fed.pending_events, &(&1.kind == "purchase"))

      assert bought.line =~ "{they} bought and ate the 🌭"
      assert bought.line =~ "for <span class=\"adena\">🪙 60 Adena</span>"
      assert result.text =~ Narrative.alert(bought.line)
      assert result.text =~ ~s(🥓 <span class="buff">Satisfied</span> settles over you.)
      # The same colours as the chronicle row, because it is the same sentence.
      assert result.text =~ ~s(<span class="hp">)
    end

    test "and about a blade, which also says what it cost" do
      {armed, result} = Player.purchase(hero(), "weapon", 2)
      [bought] = Enum.filter(armed.pending_events, &(&1.kind == "purchase"))

      assert bought.line =~ ~r/\{they\} bought the .+ for .+Adena.+ and took it in hand\./
      assert result.text == Narrative.alert(bought.line)
    end

    test "and about the run's beginning, which says who it was" do
      {born, flash} = Player.initialize(%Player{}, Constants.race(2), "Hero")
      [began] = Enum.filter(born.pending_events, &(&1.kind == "start"))

      assert flash.text == Narrative.alert(began.line)

      assert began.line =~
               ~r/\{they\} set out as a \w+ (youth|adult|elder) of \d+ seasons, bearing a /

      assert began.line =~ "🪙 450 Adena</span> tribute."
      refute flash.text =~ ~r/\{[a-z]+\}/
    end
  end
end
