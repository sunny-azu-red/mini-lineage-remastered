defmodule MiniLineageWeb.PathsTest do
  @moduledoc """
  The URLs, declared twice: once in the router as live routes, once in `Paths` as the links the
  game builds. Nothing else compares the two, so a screen added to one and forgotten in the other
  would give a link that 404s or a route nobody can reach.
  """
  use ExUnit.Case, async: true

  alias MiniLineage.Game.Format
  alias MiniLineageWeb.{Paths, Router}

  # Every live action the router answers to, and the path it answers on.
  defp routed do
    Router
    |> Phoenix.Router.routes()
    |> Enum.filter(&(&1.plug == Phoenix.LiveView.Plug))
    |> Enum.map(&{&1.plug_opts, &1.path})
  end

  test "every screen the game links to is a route the router answers" do
    paths = routed() |> Enum.map(&elem(&1, 1)) |> MapSet.new()

    for screen <-
          ~w(battle weapons armors inn suicide death character highscores statistics races) do
      assert MapSet.member?(paths, Paths.for_screen(screen)),
             "#{screen} links to #{Paths.for_screen(screen)}, which the router does not serve"
    end
  end

  test "and every route the router answers is one the game can link to" do
    # `:root` and `:unknown` are the two the game never builds a link for: "/" is reached by name
    # and an unknown path is whatever someone typed.
    linkable =
      ~w(battle weapons armors inn suicide death character highscores statistics races error start home)
      |> MapSet.new(&Paths.for_screen/1)

    for {action, path} <- routed(), action not in [:root, :unknown] do
      assert MapSet.member?(linkable, path) or String.contains?(path, ":"),
             "#{path} (#{action}) is served but nothing links to it"
    end
  end

  describe "the two screens that share a URL" do
    test "start and home are both the root, told apart by whether a character exists" do
      assert Paths.for_screen("start") == "/"
      assert Paths.for_screen("home") == "/"
    end
  end

  describe "the board's per-race URL" do
    test "takes the slug the game makes from a race label" do
      assert Paths.for_screen("highscores", Format.slugify("Dark Elf")) == "/highscores/dark-elf"
    end

    test "and falls back to the whole board without one" do
      assert Paths.for_screen("highscores") == "/highscores"
      assert Paths.for_screen("highscores", nil) == "/highscores"
    end
  end

  test "a screen with no URL of its own resolves to the root rather than crashing" do
    # The error screen is reachable, but nothing deep-links back into it.
    assert Paths.for_screen("nonsense") == "/"
  end
end
