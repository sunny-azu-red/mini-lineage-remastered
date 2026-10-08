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
    live "/battle", GameLive, :battle
    live "/shop/weapons", GameLive, :weapons
    live "/shop/armors", GameLive, :armors
    live "/inn", GameLive, :inn
    live "/class-master", GameLive, :class_master
    live "/symbol-maker", GameLive, :symbol_maker
    live "/suicide", GameLive, :suicide

    # Every record is public, being on the board, so there is nothing here to gate.
    live "/character/:id", GameLive, :character
    live "/highscores", GameLive, :highscores
    live "/highscores/:race", GameLive, :highscores
    live "/statistics", GameLive, :statistics
    live "/races", GameLive, :races
    live "/error", GameLive, :error

    # No glob: a catch-all is a soft 404. Phoenix raises for what it does not route and `ErrorHTML`
    # draws it.
  end
end
