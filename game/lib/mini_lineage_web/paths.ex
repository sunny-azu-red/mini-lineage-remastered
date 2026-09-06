defmodule MiniLineageWeb.Paths do
  @moduledoc "The link-worthy URLs, used in both directions. Access rules live in `Access`, not here."

  @routes [
    {"battle", "/battle"},
    {"weapons", "/shop/weapons"},
    {"armors", "/shop/armors"},
    {"inn", "/inn"},
    {"suicide", "/suicide"},
    {"death", "/death"},
    {"character", "/character"},
    {"highscores", "/highscores"},
    {"statistics", "/statistics"},
    {"races", "/races"},
    {"error", "/error"}
  ]

  @highscores_prefix "/highscores/"

  @doc "'start' and 'home' share '/', disambiguated by whether a character exists."
  def for_screen(screen, race_slug \\ nil)
  def for_screen(screen, _slug) when screen in ["start", "home"], do: "/"
  def for_screen("highscores", slug) when is_binary(slug), do: @highscores_prefix <> slug

  def for_screen(screen, _slug) do
    case List.keyfind(@routes, screen, 0) do
      {_, path} -> path
      # 'error' has no link-worthy URL and nothing to deep-link back into.
      nil -> "/"
    end
  end
end
