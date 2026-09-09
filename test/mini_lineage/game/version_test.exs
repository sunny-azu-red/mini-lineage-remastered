defmodule MiniLineage.Game.VersionTest do
  @moduledoc """
  What the running build calls itself.

  This is not cosmetic. `release?/1` is what withholds error detail from players, so a build that
  fails to identify itself as a release keeps handing out exception messages — which is exactly
  what happened before config/prod.exs stamped the sha: a deployed release reported "development",
  linked no commit, and showed the reason on its error pages.

  Not async: these move APP_VERSION and the stamped application env, both global.
  """
  use ExUnit.Case, async: false

  alias MiniLineage.Game.Version

  setup do
    stamped = Application.get_env(:mini_lineage, :app_version)

    on_exit(fn ->
      System.delete_env("APP_VERSION")

      if stamped,
        do: Application.put_env(:mini_lineage, :app_version, stamped),
        else: Application.delete_env(:mini_lineage, :app_version)
    end)

    System.delete_env("APP_VERSION")
    Application.delete_env(:mini_lineage, :app_version)

    :ok
  end

  describe "which version is reported" do
    test "APP_VERSION wins, so a deployment can name itself" do
      System.put_env("APP_VERSION", "abc1234")
      Application.put_env(:mini_lineage, :app_version, "9999999")

      assert Version.current() == "abc1234"
    end

    test "otherwise the sha stamped into the build at compile time" do
      Application.put_env(:mini_lineage, :app_version, "1a2b3c4")

      assert Version.current() == "1a2b3c4"
    end

    test "an EMPTY APP_VERSION is absent, not a version" do
      # A Docker build arg left unset arrives as "", which is truthy in Elixir — take it as a
      # version and the stamped sha is shadowed by nothing at all.
      System.put_env("APP_VERSION", "")
      Application.put_env(:mini_lineage, :app_version, "1a2b3c4")

      assert Version.current() == "1a2b3c4"
    end

    test "and with neither, it says plainly that it is a debug build" do
      assert Version.current() == "⚡ development"
      refute Version.release?(Version.current())
    end

    test "and there is no third answer: a nameless production build never gets built" do
      # config/prod.exs raises rather than stamp nothing, so the only way to reach the fallback
      # above is to be a debug build. A deployed footer therefore always names a commit.
      assert Version.current() == "⚡ development"
    end
  end

  describe "what counts as a release" do
    test "a short sha, of the length `git rev-parse --short=7` prints" do
      assert Version.release?("7095a47")
      assert Version.release?("ABCDEF0")
    end

    test "a FULL sha does not, which is why CI must truncate the one it is handed" do
      refute Version.release?(String.duplicate("a", 40))
    end

    test "nor does anything else that might end up in the field" do
      refute Version.release?("⚡ development")
      refute Version.release?("")
      refute Version.release?("v1.5.0")
      refute Version.release?("7095a4")
      refute Version.release?("7095a47-dirty")
      refute Version.release?("zzzzzzz")
    end
  end

  describe "the commit link" do
    test "points at the commit a release was built from" do
      assert Version.commit_url("7095a47") ==
               "https://github.com/sunny-azu-red/mini-lineage-remastered/commit/7095a47"
    end

    test "and there is none for a build that is not a release" do
      assert Version.commit_url("⚡ development") == nil
    end
  end

  describe "the stamp itself" do
    test "a build that stamps a sha links its commit" do
      Application.put_env(:mini_lineage, :app_version, "7095a47")

      assert Version.release?(Version.current())
      assert Version.commit_url(Version.current())
    end
  end

  describe "showing internals" do
    test "is a property of the build, not of whether it knows its version" do
      Application.put_env(:mini_lineage, :debug_build, false)
      on_exit(fn -> Application.put_env(:mini_lineage, :debug_build, true) end)

      # Whatever it calls itself, a production build shows a player nothing.
      refute Version.release?(Version.current())
      refute Version.debug_build?()
    end

    test "is on by default, so a build that says nothing about itself is treated as local" do
      assert Version.debug_build?()
    end
  end
end
