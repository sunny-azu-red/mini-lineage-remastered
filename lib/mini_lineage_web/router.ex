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

    # Rules §14: each town at its own address, written out one by one so that none of them is a
    # pattern that would answer a slug the game does not have.
    for slug <- MiniLineageWeb.Paths.towns() do
      live "/#{slug}", GameLive, :town
      live "/#{slug}/gatekeeper", GameLive, :gatekeeper
    end

    # No glob: a catch-all is a soft 404. Phoenix raises for what it does not route and `ErrorHTML`
    # draws it.
  end
end
