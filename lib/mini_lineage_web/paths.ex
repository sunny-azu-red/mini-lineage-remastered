defmodule MiniLineageWeb.Paths do
  @moduledoc "The link-worthy URLs. Access rules live in `Access`, not here."

  @routes [{"races", "/races"}, {"error", "/error"}]

  @doc """
  'start' and 'home' both live at '/': they are the two states of one browser, told apart by
  whether it has a character rather than by the address.
  """
  def for_screen(screen) do
    case List.keyfind(@routes, screen, 0) do
      {_, path} -> path
      nil -> "/"
    end
  end
end
