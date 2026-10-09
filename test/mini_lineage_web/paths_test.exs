defmodule MiniLineageWeb.PathsTest do
  @moduledoc """
  The URLs, declared twice: once in the router as live routes, once in `Paths` as the links the
  game builds. Nothing else compares the two, so a screen added to one and forgotten in the other
  would give a link that 404s or a route nobody can reach.
  """
  use ExUnit.Case, async: true

  alias MiniLineage.Game.Rules
  alias MiniLineageWeb.{Paths, Router}

  defp places do
    [{"start", nil}, {"races", nil}, {"error", nil}, {"character", nil}] ++
      for slug <- Paths.towns(), screen <- ~w(town gatekeeper), do: {screen, slug}
  end

  defp routed do
    Router
    |> Phoenix.Router.routes()
    |> Enum.filter(&(&1.plug == Phoenix.LiveView.Plug))
    |> Enum.map(& &1.path)
    |> MapSet.new()
  end

  test "every place links to a route the router answers, and every route is linked to" do
    assert MapSet.new(places(), &Paths.for_screen/1) == routed()
  end

  test "every open town is routed, and no town that is not open yet" do
    for town <- Rules.towns() do
      assert MapSet.member?(routed(), "/#{town.slug}") == town.open?, town.slug
    end
  end

  test "an address names the town it stands in" do
    for {screen, slug} = place <- places(), screen in ~w(town gatekeeper) do
      assert Paths.town_of("http://localhost#{Paths.for_screen(place)}") == slug
    end
  end

  test "a screen with no URL of its own resolves to the root rather than crashing" do
    assert Paths.for_screen("nonsense") == "/"
  end
end
