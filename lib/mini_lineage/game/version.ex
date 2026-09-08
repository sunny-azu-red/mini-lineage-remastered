defmodule MiniLineage.Game.Version do
  @moduledoc """
  A release stamps a short git sha and links to its commit; anything else is flagged as a debug
  build. The footer names the running build either way, so an unreachable backend still tells you
  which bundle is loaded.
  """
  @commit_url "https://github.com/sunny-azu-red/mini-lineage-remastered/commit/"
  @development "⚡ development"

  @doc """
  APP_VERSION at runtime, else the sha stamped into the build by config/prod.exs, else a debug
  build. An empty APP_VERSION is treated as absent — a Docker build arg left unset arrives as "".
  """
  def current do
    with nil <- present(System.get_env("APP_VERSION")),
         nil <- present(Application.get_env(:mini_lineage, :app_version)) do
      @development
    end
  end

  defp present(value) when is_binary(value) and value != "", do: value
  defp present(_), do: nil

  @doc "A short git sha and nothing else. Gates the footer link AND whether errors show detail."
  def release?(version), do: String.match?(version, ~r/^[0-9a-f]{7}$/i)

  def commit_url(version), do: if(release?(version), do: @commit_url <> version)
end
