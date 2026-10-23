defmodule MiniLineage.Zone do
  @moduledoc """
  Puts the game in a zone for one test, since the suites play UTC: only a test of what a zone
  changes reaches for one. The zone is the node's, so never from an async module.
  """
  import ExUnit.Callbacks

  def put(zone) do
    previous = Application.fetch_env!(:mini_lineage, :time_zone)
    Application.put_env(:mini_lineage, :time_zone, zone)
    on_exit(fn -> Application.put_env(:mini_lineage, :time_zone, previous) end)
  end
end
