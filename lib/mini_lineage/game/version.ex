defmodule MiniLineage.Game.Version do
  @moduledoc """
  A release names the commit it was built from and links to it; anything else is a debug build. The
  footer says which, so an unreachable backend still tells you what is loaded.
  """
  @commit_url "https://github.com/sunny-azu-red/mini-lineage-remastered/commit/"

  # What a build with no commit to name calls itself, baked per environment so 4002 is never taken
  # for 4000. Safe as compile_env, being a constant of the environment unlike the sha. The glyph
  # lives here too, so the two cannot fall out of step.
  @name Application.compile_env(:mini_lineage, :build_label, "development")
  @glyphs %{"development" => "🔥", "testing" => "🍃"}
  @label Map.get(@glyphs, @name, "⚡") <> @name

  @doc """
  APP_VERSION at runtime, else the sha config/prod.exs stamped in, else a debug build — only two
  answers, since a production build naming no commit fails to assemble. An empty APP_VERSION counts
  as absent, because a Docker build arg left unset arrives as "".
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
  Whether this build may show its internals — false in a production one, whatever its version. Kept
  apart from `release?/1`: tying them meant an image built without APP_VERSION could not tell it was
  a release, and served exception messages to players.
  """
  def debug_build?, do: Application.get_env(:mini_lineage, :debug_build, true)

  @doc """
  The class the footer's badge wears, or nil for a build that names a commit. Matched against the
  whole label rather than derived from it, so an APP_VERSION that is not a sha is not mistaken for
  one of these.
  """
  def build_class(@label), do: "build-" <> @name
  def build_class(_release), do: nil

  @doc "A short git sha and nothing else. Gates the footer's commit link."
  def release?(version), do: String.match?(version, ~r/^[0-9a-f]{7}$/i)

  def commit_url(version), do: if(release?(version), do: @commit_url <> version)
end
