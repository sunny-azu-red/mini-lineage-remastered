defmodule MiniLineage.Characters.PresenceLogTest do
  @moduledoc """
  The debug line a character's presence writes as viewers come and go, in the tick log's shape.
  When the Halls are slow to show somebody offline, it says when the server heard the tab go, and
  how: a clean close, or a socket found dead only by its heartbeat.
  """
  use MiniLineage.DataCase, async: false

  import ExUnit.CaptureLog

  require Logger

  alias MiniLineage.Characters

  # The suite logs at :warning; the line is :debug, as the tick log's is.
  setup do
    previous = Logger.level()
    Logger.configure(level: :debug)
    on_exit(fn -> Logger.configure(level: previous) end)
  end

  test "says who is watching as viewers join and leave, and how they left" do
    session = Characters.new_session_id()
    on_exit(fn -> Characters.forget(session) end)

    log =
      capture_log([level: :debug], fn ->
        tab = spawn(fn -> receive do: (:close -> :ok) end)
        Characters.attach(session, tab)
        ref = Process.monitor(tab)
        send(tab, :close)
        assert_receive {:DOWN, ^ref, :process, ^tab, _}
        # One round trip, so the process has certainly handled the viewer's DOWN.
        Characters.snapshot(session)
      end)

    assert log =~ ~r/\[PRESENCE:\S{1,7}\] Online \| 1 viewer \(joined\)/
    assert log =~ ~r/\[PRESENCE:\S{1,7}\] Offline \| 0 viewers \(left: :normal\)/
  end
end
