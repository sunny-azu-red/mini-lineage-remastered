defmodule Mix.Tasks.Balance do
  @shortdoc "Runs a balance simulation against the live game constants"

  @moduledoc """
  The balance studies that tuned this game, ported from `scratch/*.ts`. They read the shipped
  constants, so a rebalance is re-measured by rerunning them rather than by editing them.

      mix balance                 # list the simulations
      mix balance ambush_odds     # run one
      mix balance all             # run every one

  Compiled only in :dev, so nothing here reaches a release.
  """
  use Mix.Task

  @simulations [
    {"adena_crit", MiniLineage.Scratch.AdenaCrit, "How much richer a critical hit leaves you"},
    {"ambush_odds", MiniLineage.Scratch.AmbushOdds,
     "Does each race ambush at its advertised rate"},
    {"crit_balance", MiniLineage.Scratch.CritBalance, "The study that chose the 1.9x multiplier"},
    {"economy_balance", MiniLineage.Scratch.EconomyBalance, "Can a career fund all its gear"},
    {"food_buff", MiniLineage.Scratch.FoodBuff, "Does a food buff pay for its own duration"},
    {"food_vs_regen", MiniLineage.Scratch.FoodVsRegen, "Buying 50 HP versus waiting for it"},
    {"full_progression", MiniLineage.Scratch.FullProgression,
     "One character from level 1 to the cap"},
    {"item_efficiency", MiniLineage.Scratch.ItemEfficiency,
     "Adena paid per point of attack or defense"},
    {"leveling_speed", MiniLineage.Scratch.LevelingSpeed, "Battles spent on each level"},
    {"survivability", MiniLineage.Scratch.Survivability, "How deadly one fight is at a gear tier"}
  ]

  @impl Mix.Task
  def run([]), do: list()

  def run(["all"]) do
    Mix.Task.run("app.config")
    for {_name, module, _desc} <- @simulations, do: module.run()
    :ok
  end

  def run([name]) do
    case List.keyfind(@simulations, name, 0) do
      {_name, module, _desc} ->
        Mix.Task.run("app.config")
        module.run()

      nil ->
        Mix.shell().error("Unknown simulation: #{name}\n")
        list()
        exit({:shutdown, 1})
    end
  end

  def run(_args), do: Mix.raise("Usage: mix balance [all | <simulation>]")

  defp list do
    Mix.shell().info("Balance simulations:\n")

    width = @simulations |> Enum.map(&String.length(elem(&1, 0))) |> Enum.max()

    for {name, _module, description} <- @simulations do
      Mix.shell().info("  #{String.pad_trailing(name, width)}  #{description}")
    end

    Mix.shell().info("\nRun one with `mix balance <name>`, or every one with `mix balance all`.")
  end
end
