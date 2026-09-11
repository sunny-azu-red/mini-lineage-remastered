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

  describe "the window" do
    # The table is public and keyed on monotonic milliseconds, so an entry can be planted as
    # though it were made a minute ago. Sleeping the real window would put a minute on the suite.
    defp plant(key, limiter, count, age_ms) do
      stamp = System.monotonic_time(:millisecond) - age_ms

      for _ <- 1..count,
          do: :ets.insert(:mini_lineage_rate_limit, {{key, limiter}, stamp})
    end

    test "lets the player back in once it has passed", %{key: key} do
      plant(key, :shop, 30, 61_000)

      assert RateLimit.check(key, :shop) == :ok, "a limit that never recovers is a permanent ban"
    end

    test "slides rather than resetting, so an old burst does not buy a new one", %{key: key} do
      # Half the window's worth is still current; the rest has aged out.
      plant(key, :shop, 20, 61_000)
      plant(key, :shop, 29, 1_000)

      assert RateLimit.check(key, :shop) == :ok
      assert {:error, _} = RateLimit.check(key, :shop)
    end

    test "and the retry hint points past the oldest entry still counted", %{key: key} do
      plant(key, :shop, 30, 10_000)

      assert {:error, retry_after_ms} = RateLimit.check(key, :shop)
      assert_in_delta retry_after_ms, 50_000, 1_000
    end
  end

  describe "the flood limiter" do
    test "catches what the per-action limits do not", %{key: key} do
      # 300 a minute across everything: a client firing a mix of actions stays under both the
      # battle and shop limits and is still stopped.
      for _ <- 1..300, do: assert(RateLimit.check(key, :flood) == :ok)

      assert {:error, _} = RateLimit.check(key, :flood)
    end
  end

  describe "the sweep" do
    test "drops entries no window still counts, so the table does not grow forever", %{key: key} do
      plant(key, :shop, 50, 61_000)
      plant(key, :shop, 5, 1_000)

      send(Process.whereis(RateLimit), :sweep)
      # A call would be cleaner, but the sweep is a cast-shaped timer; this waits for its mailbox.
      :sys.get_state(Process.whereis(RateLimit))

      assert length(:ets.lookup(:mini_lineage_rate_limit, {key, :shop})) == 5
    end
  end

  test "is bypassed entirely when disabled, so local development is never throttled", %{key: key} do
    Application.put_env(:mini_lineage, :rate_limit, false)

    for _ <- 1..500, do: assert(RateLimit.check(key, :shop) == :ok)
  end
end
