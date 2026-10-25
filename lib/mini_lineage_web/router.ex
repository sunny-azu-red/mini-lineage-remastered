defmodule MiniLineageWeb.Router do
  use MiniLineageWeb, :router

  alias MiniLineageWeb.Paths

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

    # The reader's kept choices reach the first draw through the session, so a reload is drawn
    # as they left it.
    live_session :game, session: {MiniLineageWeb.Kept, :session, []} do
      # One LiveView, so moving between screens is a patch; `Access.pin_screen/2` is the only gate.
      live "/", GameLive, :root
      live Paths.for_screen("races"), GameLive, :races
      live Paths.for_screen("error"), GameLive, :error
      # The browser's own character, so no id: a page anybody could open would want a public one.
      live Paths.for_screen("character"), GameLive, :character
      # The browser's own character's inventory, like its character page.
      live Paths.for_screen("inventory"), GameLive, :inventory

      # The Halls, overall and for each lineage, written out like the towns.
      live Paths.for_screen("highscores"), GameLive, :highscores

      for lineage <- Paths.lineages() do
        live Paths.for_screen({"highscores", lineage}), GameLive, :highscores
      end

      # Rules §14: each town at its own address, written out one by one so that none of them is a
      # pattern that would answer a slug the game does not have.
      for town <- Paths.towns() do
        live Paths.for_screen({"town", town}), GameLive, :town
        live Paths.for_screen({"gatekeeper", town}), GameLive, :gatekeeper
      end

      # Rules §24 and §25: each village's traders and its guild.
      for town <- Paths.villages() do
        live Paths.for_screen({"trader", town}), GameLive, :trader

        for page <- Paths.trader_pages() do
          live Paths.for_screen({"trader-" <> page, town}), GameLive, :trader_page
        end

        # Each guild at its own name, a run sent on to its own (`Paths.for_screen/2`).
        for guild <- Paths.guilds(town) do
          live "/#{town}/#{guild}", GameLive, :guild
        end
      end

      # Rules §17: a village's ground, outside it and at its own address.
      for town <- Paths.hunting_towns() do
        live Paths.for_screen({"hunt", town}), GameLive, :hunt
      end
    end

    # No glob: a catch-all is a soft 404. Phoenix raises for what it does not route and `ErrorHTML`
    # draws it.
  end
end
