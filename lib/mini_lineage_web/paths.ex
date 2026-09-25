defmodule MiniLineageWeb.Paths do
  @moduledoc "The link-worthy URLs, used in both directions. Access rules live in `Access`, not here."

  @routes [
    {"battle", "/battle"},
    {"weapons", "/shop/weapons"},
    {"armors", "/shop/armors"},
    {"inn", "/inn"},
    {"suicide", "/suicide"},
    {"highscores", "/highscores"},
    {"statistics", "/statistics"},
    {"races", "/races"},
    {"error", "/error"}
  ]

  @highscores_prefix "/highscores/"
  @character_prefix "/character/"

  @doc """
  A run's own record, addressed by its PUBLIC id — never by the session playing it. `from` is how
  the record knows where to send the reader back to.
  """
  def for_character(id, from \\ nil)
  def for_character(id, nil), do: @character_prefix <> id
  def for_character(id, from), do: "#{@character_prefix}#{id}?from=#{from}"

  @doc """
  'start', 'home' and 'death' all live at '/': they are the three states of one run, told apart by
  the character rather than by the address.
  """
  def for_screen(screen, race_slug \\ nil)
  def for_screen(screen, _slug) when screen in ["start", "home", "death"], do: "/"
  def for_screen("highscores", slug) when is_binary(slug), do: @highscores_prefix <> slug

  def for_screen(screen, _slug) do
    case List.keyfind(@routes, screen, 0) do
      {_, path} -> path
      # Every screen the game patches to is routed above; nothing else has an address but home.
      nil -> "/"
    end
  end
end
