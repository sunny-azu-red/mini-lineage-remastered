defmodule MiniLineageWeb.Plugs.ContentSecurityPolicy do
  @moduledoc """
  No inline scripts, websockets allowed for LiveView, and Google Fonts reachable over https.
  """
  @behaviour Plug

  @directives [
    "default-src 'self'",
    "base-uri 'self'",
    "font-src 'self' https: data:",
    "form-action 'self'",
    "frame-ancestors 'self'",
    "img-src 'self' data:",
    "object-src 'none'",
    "script-src 'self'",
    "script-src-attr 'none'",
    "style-src 'self' https: 'unsafe-inline'",
    "connect-src 'self' ws: wss:"
  ]

  @impl true
  def init(opts), do: opts

  # `upgrade-insecure-requests` only on https: over plain http it rewrites every redirect target to
  # https and breaks navigation.
  @impl true
  def call(%Plug.Conn{scheme: scheme} = conn, _opts) do
    directives =
      if scheme == :https, do: @directives ++ ["upgrade-insecure-requests"], else: @directives

    Plug.Conn.put_resp_header(conn, "content-security-policy", Enum.join(directives, "; "))
  end
end
