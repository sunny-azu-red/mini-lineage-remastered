defmodule MiniLineageWeb.Paths do
  @moduledoc """
  The link-worthy URLs, each segment the slug of the name the game draws for that place: a town's,
  a ground's, a guild's, a lineage's plural, or a page's below. Access rules live in `Access`.
  """

  alias MiniLineage.Game.{Constants, Format, Rules}

  # What each page with an address of its own is headed, which `Screens` draws and its address is
  # made of. A trader's page is `trader-` and what it sells.
  @names [
    {"races", "Chronicles of Ancestry"},
    {"error", "Error"},
    {"character", "Character"},
    {"highscores", "Monument of Heroes"},
    {"inventory", "Inventory"},
    {"gatekeeper", "Gatekeeper"},
    {"trader", "Traders"},
    {"trader-weapon", "Weapon Trader"},
    {"trader-armour", "Armour Trader"},
    {"trader-magic", "Magic Trader"},
    {"trader-sell", "Sell"}
  ]

  # The pages that stand in no town.
  @routes ~w(races error character highscores inventory)

  @doc "What each page with an address is headed."
  def names, do: Map.new(@names)

  defp slug(screen), do: @names |> List.keyfind!(screen, 0) |> elem(1) |> Format.slugify()

  @doc "The slug of every town the router answers, each with its Gatekeeper beside it."
  def towns, do: for(town <- Rules.towns(), town.open?, do: town.slug)

  @doc "The trader's inner pages, each one part of what a village sells or buys (rules §24)."
  def trader_pages, do: for({"trader-" <> page, _} <- @names, do: page)

  @doc "The trader's page an address's last segment names."
  def trader_page_of(segment),
    do: Enum.find(trader_pages(), &(slug("trader-" <> &1) == segment))

  @doc "The starting villages, each with its traders and guild (rules §24, §25)."
  def villages, do: for(town <- towns(), Rules.village?(town), do: town)

  @doc "The towns with a hunting ground outside them (rules §17)."
  def hunting_towns, do: for(town <- towns(), Rules.ground_of(town), do: town)

  @doc "Each village's guilds, one for each its sets learn in (rules §25), by slug."
  def guilds(village) do
    for set <- Rules.sets(),
        Rules.hometown(set.race_id) == village,
        uniq: true,
        do: guild_slug(set)
  end

  defp guild_slug(set), do: Format.slugify(Rules.guild(set.name).name)

  @doc "Each lineage's own board in the Halls, by the plural its filter button reads."
  def lineages, do: Enum.map(Constants.races(), &lineage/1)

  def lineage(race), do: Format.slugify(race.plural)

  @doc """
  A place's address. A town is at its own slug, so the URL is where you stand; '/' is game start
  for a visitor, and wherever a character stands for anybody else.
  """
  def for_screen({"town", town}) when is_binary(town), do: "/#{town}"

  def for_screen({"trader-" <> _ = screen, town}) when is_binary(town),
    do: "#{for_screen({"trader", town})}/#{slug(screen)}"

  def for_screen({screen, town}) when screen in ~w(gatekeeper trader) and is_binary(town),
    do: "/#{town}/#{slug(screen)}"

  def for_screen({"guild", _town}),
    do: raise(ArgumentError, "a guild is at the run's own guild's name: for_screen/2")

  def for_screen({"hunt", town}) when is_binary(town),
    do: "/#{town}/#{Rules.ground_of(town).slug}"

  def for_screen({"highscores", lineage}) when is_binary(lineage),
    do: "#{for_screen("highscores")}/#{lineage}"

  def for_screen({screen, _town}), do: for_screen(screen)
  def for_screen(screen) when screen in @routes, do: "/#{slug(screen)}"
  def for_screen(_screen), do: "/"

  @doc "A place's address for a run, which a village's guild needs: the guild its set learns in."
  def for_screen({"guild", town}, player) when is_binary(town),
    do: "/#{town}/#{guild_slug(Rules.set(player.race_id, player.path))}"

  def for_screen(place, _player), do: for_screen(place)

  @doc "The town a routed address stands in, which the router has already checked is one."
  def town_of(uri), do: uri |> segments() |> hd()

  @doc "The lineage a Halls address is filtered to, or nil for all of them."
  def lineage_of(uri), do: uri |> segments() |> Enum.at(1)

  defp segments(uri),
    do: uri |> URI.parse() |> Map.fetch!(:path) |> String.split("/", trim: true)
end
