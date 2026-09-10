defmodule MiniLineage.Game.Version do
  @moduledoc """
  A release names the commit it was built from and links to it; anything else is a debug build. The
  footer says which, so an unreachable backend still tells you what is loaded.
  """
  @commit_url "https://github.com/sunny-azu-red/mini-lineage-remastered/commit/"

  # What a build with no commit to name calls itself. Baked per environment, so the browser
  # suites' server on 4002 is never mistaken for the dev server on 4000.
  @label Application.compile_env(:mini_lineage, :build_label, "⚡ development")

  @doc """
  APP_VERSION at runtime, else the sha config/prod.exs stamped in, else a debug build. Only two
  answers: a production build that could name no commit fails to build at all.

  An empty APP_VERSION counts as absent — a Docker build arg left unset arrives as "".
  """
  def current do
    with nil <- present(System.get_env("APP_VERSION")),
         nil <- present(Application.get_env(:mini_lineage, :app_version)) do
      @label
    end
  end

  defp present(value) when is_binary(value) and value != "", do: value
  defp present(_), do: nil

  @doc """
  Whether this build may show its internals — false in a production one, whatever its version.

  Kept apart from `release?/1` on purpose. Tying the two meant an image built without APP_VERSION
  could not tell it was a release, and went on serving exception messages to players.
  """
  def debug_build?, do: Application.get_env(:mini_lineage, :debug_build, true)

  @doc "A short git sha and nothing else. Gates the footer's commit link."
  def release?(version), do: String.match?(version, ~r/^[0-9a-f]{7}$/i)

  def commit_url(version), do: if(release?(version), do: @commit_url <> version)
end
