defmodule MiniLineageWeb.PathsTest do
  @moduledoc """
  The URLs, declared twice: once in the router as live routes, once in `Paths` as the links the
  game builds. Nothing else compares the two, so a screen added to one and forgotten in the other
  would give a link that 404s or a route nobody can reach. And every address says what its link
  says: each segment is the slug of a name the game draws.
  """
  use ExUnit.Case, async: true

  alias MiniLineage.Game.{Constants, Format, Rules}
  alias MiniLineageWeb.{Paths, Router}

  # A guild's address is the run's own set's, so each starting set stands in for a run.
  defp places do
    [{"start", nil}, {"races", nil}, {"error", nil}, {"character", nil}, {"highscores", nil}] ++
      [{"inventory", nil}] ++
      for(slug <- Paths.villages(), do: {"trader", slug}) ++
      for(slug <- Paths.villages(), page <- Paths.trader_pages(), do: {"trader-" <> page, slug}) ++
      for(slug <- Paths.towns(), screen <- ~w(town gatekeeper), do: {screen, slug}) ++
      for(slug <- Paths.hunting_towns(), do: {"hunt", slug}) ++
      for(lineage <- Paths.lineages(), do: {"highscores", lineage}) ++
      for set <- Rules.sets(), do: {"guild", Rules.hometown(set.race_id), set}
  end

  defp address({"guild", slug, set}), do: Paths.for_screen({"guild", slug}, set)
  defp address(place), do: Paths.for_screen(place)

  defp town({screen, slug}), do: {screen, slug}
  defp town({screen, slug, _set}), do: {screen, slug}

  defp routed do
    Router
    |> Phoenix.Router.routes()
    |> Enum.filter(&(&1.plug == Phoenix.LiveView.Plug))
    |> Enum.map(& &1.path)
    |> MapSet.new()
  end

  test "every place links to a route the router answers, and every route is linked to" do
    assert MapSet.new(places(), &address/1) == routed()
  end

  test "every open town is routed, and no town that is not open yet" do
    for town <- Rules.towns() do
      assert MapSet.member?(routed(), "/#{town.slug}") == town.open?, town.slug
    end
  end

  test "an address names the town it stands in" do
    for place <- places(),
        {screen, slug} = town(place),
        screen in ~w(town gatekeeper hunt trader guild) do
      assert Paths.town_of("http://localhost#{address(place)}") == slug
    end
  end

  test "a Halls address names the lineage it is filtered to, or none" do
    for {"highscores", lineage} = place <- places() do
      assert Paths.lineage_of("http://localhost#{address(place)}") == lineage
    end
  end

  test "a screen with no URL of its own resolves to the root rather than crashing" do
    assert Paths.for_screen("nonsense") == "/"
  end

  test "every routed segment is the slug of the name that leads there" do
    names =
      Enum.map(Rules.towns(), & &1.name) ++
        Enum.map(Rules.grounds(), & &1.name) ++
        Map.values(Paths.names()) ++
        Enum.map(Constants.races(), & &1.plural) ++
        Enum.map(Rules.sets(), &Rules.guild(&1.name).name)

    slugs = MapSet.new(names, &Format.slugify/1)

    for path <- routed(), segment <- String.split(path, "/", trim: true) do
      assert segment in slugs, "#{path}: #{inspect(segment)} names nothing the game draws"
    end
  end

  test "a guild is at its own name, and a village with two has an address for each" do
    assert Paths.guilds("talking-island-village") == ~w(warriors-guild mystics-guild)
    assert Paths.guilds("elven-village") == ~w(evas-sanctuary)
  end

  test "a lineage's board is at the plural its filter button reads" do
    assert "/monument-of-heroes/dark-elves" in routed()
  end
end
