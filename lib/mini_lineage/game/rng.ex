defmodule MiniLineage.Game.Rng do
  @moduledoc """
  The seam that replaces `Math.random()`. Per-process, so a character's stream is its own and a
  test can install a deterministic source without touching global state.

  Draw ORDER is load-bearing across the whole fight path — see the golden master.
  """
  @key :mini_lineage_rng

  @doc "Installs a deterministic source for the calling process."
  def put_source(fun) when is_function(fun, 0), do: Process.put(@key, fun)

  @doc "A float in [0.0, 1.0), matching `Math.random()`'s range."
  def random do
    case Process.get(@key) do
      nil -> :rand.uniform_real()
      fun -> fun.()
    end
  end
end
