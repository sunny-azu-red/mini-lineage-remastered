defmodule MiniLineageWeb.Paths do
  @moduledoc "The link-worthy URLs. Access rules live in `Access`, not here."

  alias MiniLineage.Game.Rules

  @routes [{"races", "/races"}, {"error", "/error"}]

  @doc "The slug of every town the router answers, each with its Gatekeeper beside it."
  def towns, do: for(town <- Rules.towns(), town.open?, do: town.slug)

  @doc """
  A place's address. A town is at its own slug, so the URL is where you stand; '/' is game start
  for a visitor, and wherever a character stands for anybody else.
  """
  def for_screen({"town", slug}) when is_binary(slug), do: "/#{slug}"
  def for_screen({"gatekeeper", slug}) when is_binary(slug), do: "/#{slug}/gatekeeper"
  def for_screen({screen, _town}), do: for_screen(screen)

  def for_screen(screen) do
    case List.keyfind(@routes, screen, 0) do
      {_, path} -> path
      nil -> "/"
    end
  end

  @doc "The town a routed address stands in, which the router has already checked is one."
  def town_of(uri),
    do: uri |> URI.parse() |> Map.fetch!(:path) |> String.split("/", trim: true) |> hd()
end
