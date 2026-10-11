defmodule MiniLineageWeb.Router do
  use MiniLineageWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug MiniLineageWeb.Plugs.CharacterSession
    plug :put_root_layout, html: {MiniLineageWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug MiniLineageWeb.Plugs.ContentSecurityPolicy
  end

  scope "/", MiniLineageWeb do
    pipe_through :browser

    # One LiveView, so moving between screens is a patch; `Access.pin_screen/2` is the only gate.
    live "/", GameLive, :root
    live "/races", GameLive, :races
    live "/error", GameLive, :error
    # The browser's own character, so no id: a page anybody could open would want a public one.
    live "/character", GameLive, :character
    # The browser's own character's inventory, like its character page.
    live "/inventory", GameLive, :inventory

    # The Halls, overall and for each lineage, written out like the towns.
    live "/highscores", GameLive, :highscores

    for lineage <- MiniLineageWeb.Paths.lineages() do
      live "/highscores/#{lineage}", GameLive, :highscores
    end

    # Rules §14: each town at its own address, written out one by one so that none of them is a
    # pattern that would answer a slug the game does not have.
    for slug <- MiniLineageWeb.Paths.towns() do
      live "/#{slug}", GameLive, :town
      live "/#{slug}/gatekeeper", GameLive, :gatekeeper
    end

    # Rules §24: each village's shop.
    for slug <- MiniLineageWeb.Paths.villages() do
      live "/#{slug}/trader", GameLive, :trader
    end

    # Rules §17: a village's ground, outside it and at its own address.
    for slug <- MiniLineageWeb.Paths.hunting_towns() do
      live "/#{slug}/#{MiniLineage.Game.Rules.ground_of(slug).slug}", GameLive, :hunt
    end

    # No glob: a catch-all is a soft 404. Phoenix raises for what it does not route and `ErrorHTML`
    # draws it.
  end
end
