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
    longpoll: [connect_info: [session: @session_options]]

  # A digested filename is content addressed, so it can be held for ever. Phoenix appends no
  # `?vsn=d` to one, and that query is all Plug.Static caches this way by default — so without this
  # every asset is revalidated on every load. Development keeps its names, and is left alone.
  @digested_cache_control if code_reloading?,
                            do: "public",
                            else: "public, max-age=31536000, immutable"

  plug Plug.Static,
    at: "/assets",
    from: {:mini_lineage, "priv/static/assets"},
    gzip: not code_reloading?,
    cache_control_for_etags: @digested_cache_control

  # `only_matching` for the favicon: a release links it by its digested name, `favicon-<hash>.ico`,
  # which `only` does not match, so the icon fell through to the router's 404.
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
