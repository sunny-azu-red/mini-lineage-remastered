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

    # No glob: a catch-all is a soft 404. Phoenix raises for what it does not route and `ErrorHTML`
    # draws it.
  end
end
