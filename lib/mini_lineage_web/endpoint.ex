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
    secure: System.get_env("IN_DOCKER") == "true",
    max_age: Application.compile_env(:mini_lineage, :character_ttl_hours, 24) * 60 * 60
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: [connect_info: [session: @session_options]]

  plug Plug.Static,
    at: "/",
    from: :mini_lineage,
    gzip: not code_reloading?,
    only: MiniLineageWeb.static_paths(),
    raise_on_missing_only: code_reloading?

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :mini_lineage
  end

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
end
