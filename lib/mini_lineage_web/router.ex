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

    # Every screen is the same LiveView, so moving between them is a patch, not a full mount —
    # and `Access.pin_screen/2` in handle_params/3 is the only gate any of them pass through.
    live "/", GameLive, :root
    live "/battle", GameLive, :battle
    live "/shop/weapons", GameLive, :weapons
    live "/shop/armors", GameLive, :armors
    live "/inn", GameLive, :inn
    live "/suicide", GameLive, :suicide

    # One record, one route. Every character's is public — it is on the board — so there is nothing
    # here to gate, and yours is simply the one whose id matches your session's.
    live "/character/:id", GameLive, :character
    live "/highscores", GameLive, :highscores
    live "/highscores/:race", GameLive, :highscores
    live "/statistics", GameLive, :statistics
    live "/races", GameLive, :races
    live "/error", GameLive, :error

    # No glob. Redirecting an unrecognised path to Town is a soft 404: nothing is said, the address
    # is thrown away, and a mistyped stylesheet comes back as HTML. Phoenix raises for what it does
    # not route, and `ErrorHTML` draws it in the game's own shell.
  end
end
