defmodule MiniLineageWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :mini_lineage

  # An opaque character id and nothing else, signed. `max_age` is the same window the character row
  # itself lives for, so closing the browser cannot lose a character the database still holds.
  @session_options [
    store: :cookie,
    key: "_mini_lineage_key",
    signing_salt: "boRfKEv2",
    same_site: "Lax",
    http_only: true,
    secure: Application.compile_env(:mini_lineage, :secure_cookie, false),
    max_age: Application.compile_env!(:mini_lineage, :character_ttl_hours) * 60 * 60
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    # A closed long-poll tab is noticed only by its missing polls, within 1.5 to 3 windows: 5s
    # rather than Phoenix's 10 puts a closed tab offline in seconds, for one idle poll per window.
    longpoll: [window_ms: 5_000, connect_info: [session: @session_options]]

  # A digested link carries `?vsn=d`, which Plug.Static already holds for a year; anything else
  # revalidates, so an undigested name is never served stale after a deploy.
  # `only_matching`: a release links the favicon as `favicon-<hash>.ico`, which `only` does not match.
  plug Plug.Static,
    at: "/",
    from: :mini_lineage,
    gzip: not code_reloading?,
    only: MiniLineageWeb.static_paths(),
    only_matching: ~w(favicon),
    raise_on_missing_only: code_reloading?

  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :mini_lineage
  end

  # The container's healthcheck, answered before the session and the request log: it sends no
  # cookie, so as a page it would mint a visitor and start a character process on every probe.
  plug :health

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug MiniLineageWeb.Router

  defp health(%Plug.Conn{request_path: "/health"} = conn, _opts),
    do: conn |> Plug.Conn.send_resp(200, "ok") |> Plug.Conn.halt()

  defp health(conn, _opts), do: conn
end
