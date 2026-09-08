defmodule MiniLineageWeb.Router do
  use MiniLineageWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug MiniLineageWeb.Plugs.CharacterSession
    plug :fetch_live_flash
    plug :put_root_layout, html: {MiniLineageWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug MiniLineageWeb.Plugs.ContentSecurityPolicy
  end

  scope "/", MiniLineageWeb do
    pipe_through :browser

    # Every screen is the same LiveView, so moving between them is a patch, not a full mount —
    # and `Access.pin_screen/2` in handle_params/3 is the only gate any of them pass through.
    live "/", GameLive, :root
    live "/battle", GameLive, :battle
    live "/shop/weapons", GameLive, :weapons
    live "/shop/armors", GameLive, :armors
    live "/inn", GameLive, :inn
    live "/suicide", GameLive, :suicide
    live "/death", GameLive, :death
    live "/character", GameLive, :character
    live "/highscores", GameLive, :highscores
    live "/highscores/:race", GameLive, :highscores
    live "/statistics", GameLive, :statistics
    live "/races", GameLive, :races
    live "/error", GameLive, :error

    # The game owns every URL. An unrecognised path is not an error — it resolves to Town (or Game
    # Start, once pinned) and the address bar is corrected, exactly as the reference's SPA fallback
    # did. Must stay last: a glob would otherwise shadow every route above it.
    live "/*unknown", GameLive, :unknown
  end
end
