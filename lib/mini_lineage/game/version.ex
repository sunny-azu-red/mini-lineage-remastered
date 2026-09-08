defmodule MiniLineage.Game.Version do
  @moduledoc """
  A release stamps a short git sha and links to its commit; anything else is flagged as a debug
  build. The footer names the running build either way, so an unreachable backend still tells you
  which bundle is loaded.
  """
  @commit_url "https://github.com/sunny-azu-red/mini-lineage-remastered/commit/"
  @development "⚡ development"

  def current, do: System.get_env("APP_VERSION") || @development

  @doc "Shared with the reference's definition so the two can't disagree on what a release is."
  def release?(version), do: String.match?(version, ~r/^[0-9a-f]{7}$/i)

  def commit_url(version), do: if(release?(version), do: @commit_url <> version)
end
