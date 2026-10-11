defmodule MiniLineageWeb.Paths do
  @moduledoc "The link-worthy URLs. Access rules live in `Access`, not here."

  alias MiniLineage.Game.{Constants, Format, Rules}

  @routes [
    {"races", "/races"},
    {"error", "/error"},
    {"character", "/character"},
    {"highscores", "/highscores"},
    {"inventory", "/inventory"}
  ]

  @doc "The slug of every town the router answers, each with its Gatekeeper beside it."
  def towns, do: for(town <- Rules.towns(), town.open?, do: town.slug)

  @doc "The starting villages, each with its shop (rules §24)."
  def villages, do: for(town <- towns(), Rules.village?(town), do: town)

  @doc "The towns with a hunting ground outside them (rules §17)."
  def hunting_towns, do: for(town <- towns(), Rules.ground_of(town), do: town)

  @doc "Each lineage's own board in the Halls, by its slug."
  def lineages, do: Enum.map(Constants.races(), &Format.slugify(&1.label))

  @doc """
  A place's address. A town is at its own slug, so the URL is where you stand; '/' is game start
  for a visitor, and wherever a character stands for anybody else.
  """
  def for_screen({"town", slug}) when is_binary(slug), do: "/#{slug}"
  def for_screen({"gatekeeper", slug}) when is_binary(slug), do: "/#{slug}/gatekeeper"

  def for_screen({"trader", slug}) when is_binary(slug), do: "/#{slug}/trader"
  def for_screen({"trainer", slug}) when is_binary(slug), do: "/#{slug}/trainer"

  def for_screen({"hunt", slug}) when is_binary(slug),
    do: "/#{slug}/#{Rules.ground_of(slug).slug}"

  def for_screen({"highscores", lineage}) when is_binary(lineage), do: "/highscores/#{lineage}"
  def for_screen({screen, _town}), do: for_screen(screen)

  def for_screen(screen) do
    case List.keyfind(@routes, screen, 0) do
      {_, path} -> path
      nil -> "/"
    end
  end

  @doc "The town a routed address stands in, which the router has already checked is one."
  def town_of(uri), do: uri |> segments() |> hd()

  @doc "The lineage a Halls address is filtered to, or nil for all of them."
  def lineage_of(uri), do: uri |> segments() |> Enum.at(1)

  defp segments(uri),
    do: uri |> URI.parse() |> Map.fetch!(:path) |> String.split("/", trim: true)
end
