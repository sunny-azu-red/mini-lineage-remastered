defmodule MiniLineageWeb.NotFoundError do
  @moduledoc """
  A route the game has, for a thing it does not: a record whose character was never real, or whose
  row has since been purged. `plug_status` makes Phoenix render the game's own 404, not a 500.
  """
  defexception message: "no such record", plug_status: 404
end
