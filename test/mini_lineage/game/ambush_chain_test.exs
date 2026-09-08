defmodule MiniLineage.Game.AmbushChainTest do
  @moduledoc """
  The chain ambush engine. Neither the golden master nor the balance simulations reach this: both
  drive a simulation harness that rolls its own ambush and never tracks a streak, so the Hexed
  debuff is applied only by the shipped fight path.
  """
  use ExUnit.Case, async: true

  alias MiniLineage.Game.{Actions, Constants, Player, Rng}

  defp orc do
    {player, _} = Player.initialize(%Player{}, Constants.race(1), "Grok")
    # Tanky enough to survive every fight below.
    %{player | health: 5_000}
  end

  defp always_ambush, do: Rng.put_source(fn -> 0.0 end)
  defp never_ambush, do: Rng.put_source(fn -> 0.999999 end)

  defp hexed?(player), do: Enum.any?(player.effects, &(&1.id == "hexed"))

  test "one ambush is not enough to hex" do
    always_ambush()
    {player, {:ok, result}} = Actions.fight(orc())

    assert result.ambushed
    assert player.consecutive_ambushes == 1
    refute hexed?(player)
  end

  test "two consecutive ambushes inflict Hexed" do
    always_ambush()
    {player, _} = Actions.fight(orc())
    {player, _} = Actions.fight(player)

    assert player.consecutive_ambushes == 2
    assert hexed?(player)
  end

  test "Hexed raises ambush risk and lowers crit, snowballing the danger" do
    always_ambush()
    {clean, _} = Actions.fight(orc())
    {hexed, _} = Actions.fight(clean)

    assert Player.stats(hexed).ambush_risk == Player.stats(clean).ambush_risk + 4
    assert Player.stats(hexed).crit == max(0, Player.stats(clean).crit - 2)
  end

  test "a fight without an ambush breaks the streak" do
    always_ambush()
    {player, _} = Actions.fight(orc())
    assert player.consecutive_ambushes == 1

    never_ambush()
    {player, {:ok, result}} = Actions.fight(player)

    refute result.ambushed
    assert player.consecutive_ambushes == 0
  end

  test "an ambush is resolved by fighting again, with no precondition and no penalty" do
    always_ambush()
    {ambushed, _} = Actions.fight(orc())
    assert ambushed.ambushed

    # Navigating away mid-ambush is not punished — the next fight simply resolves it.
    {resolved, {:ok, result}} = Actions.fight(%{ambushed | current_screen: "inn"})

    assert result.outcome.xp_gained > 0
    assert resolved.current_screen == "battle"
  end
end
