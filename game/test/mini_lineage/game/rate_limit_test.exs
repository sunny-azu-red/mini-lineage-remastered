defmodule MiniLineage.Game.RateLimitTest do
  @moduledoc """
  Throttling is bypassed in development, so the browser walkthrough cannot exercise it — this
  turns it on explicitly and drives a window to its limit.
  """
  use ExUnit.Case, async: false

  alias MiniLineage.Game.RateLimit

  setup do
    Application.put_env(:mini_lineage, :rate_limit, true)
    on_exit(fn -> Application.put_env(:mini_lineage, :rate_limit, false) end)

    {:ok, key: "character-#{System.unique_integer([:positive])}"}
  end

  test "allows a burst up to the limit, then refuses with a retry hint", %{key: key} do
    for _ <- 1..30, do: assert(RateLimit.check(key, :shop) == :ok)

    assert {:error, retry_after_ms} = RateLimit.check(key, :shop)
    assert retry_after_ms > 0
    assert retry_after_ms <= 60_000
  end

  test "limits are per character, not global", %{key: key} do
    for _ <- 1..30, do: RateLimit.check(key, :shop)
    assert {:error, _} = RateLimit.check(key, :shop)

    assert RateLimit.check("someone-else", :shop) == :ok
  end

  test "limits are per action, so shopping does not throttle fighting", %{key: key} do
    for _ <- 1..30, do: RateLimit.check(key, :shop)
    assert {:error, _} = RateLimit.check(key, :shop)

    assert RateLimit.check(key, :battle) == :ok
  end

  test "is bypassed entirely when disabled, so local development is never throttled", %{key: key} do
    Application.put_env(:mini_lineage, :rate_limit, false)

    for _ <- 1..500, do: assert(RateLimit.check(key, :shop) == :ok)
  end
end
