defmodule MiniLineageWeb.NotFoundError do
  @moduledoc """
  A route the game has, for a thing it does not: a record whose character was never real, or whose
  row has since been purged.

  `plug_status` is the whole of it — Phoenix reads it and renders the game's own 404 rather than a
  500. A page of its own saying the same thing in different words was the last place in the game
  answering "this does not exist" with a 200, which left one road leading nowhere by two routes.
  """
  defexception message: "no such record", plug_status: 404
end
