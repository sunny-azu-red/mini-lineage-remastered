defmodule MiniLineage.Test.Lcg do
  @moduledoc """
  The golden master's own generator, ported bit-for-bit. The JavaScript reference,
  `seed = (seed * 1103515245 + 12345) & 0x7fffffff`, ROUNDS a product past 2^53 before `&`
  truncates it, so a literal Elixir transliteration diverges by the second draw. Forcing float64
  arithmetic reproduces the JS stream exactly, verified over 1,000,000 draws.
  """
  import Bitwise

  @key :lcg_seed
  @modulus 0x7FFFFFFF

  @doc "Installs this generator as the calling process's randomness source."
  def install(seed) do
    Process.put(@key, seed)
    MiniLineage.Game.Rng.put_source(&next/0)
  end

  def next do
    seed = Process.get(@key)
    next_seed = band(trunc(seed * 1.0 * 1_103_515_245.0 + 12_345.0), @modulus)
    Process.put(@key, next_seed)

    next_seed / @modulus
  end
end
