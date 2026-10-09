defmodule MiniLineageWeb.PathsTest do
  @moduledoc """
  The URLs, declared twice: once in the router as live routes, once in `Paths` as the links the
  game builds. Nothing else compares the two, so a screen added to one and forgotten in the other
  would give a link that 404s or a route nobody can reach.
  """
  use ExUnit.Case, async: true

  alias MiniLineageWeb.{Paths, Router}

  @screens ~w(start home races error)

  defp routed do
    Router
    |> Phoenix.Router.routes()
    |> Enum.filter(&(&1.plug == Phoenix.LiveView.Plug))
    |> Enum.map(& &1.path)
    |> MapSet.new()
  end

  test "every screen links to a route the router answers, and every route is linked to" do
    assert MapSet.new(@screens, &Paths.for_screen/1) == routed()
  end

  test "start and home are both the root, one browser's two states" do
    for screen <- ~w(start home), do: assert(Paths.for_screen(screen) == "/", screen)
  end

  test "a screen with no URL of its own resolves to the root rather than crashing" do
    assert Paths.for_screen("nonsense") == "/"
  end
end
