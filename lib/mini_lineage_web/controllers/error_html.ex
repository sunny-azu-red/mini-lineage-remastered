defmodule MiniLineageWeb.ErrorHTML do
  @moduledoc """
  Errors Phoenix itself raises, before a LiveView ever mounts — a bad URL, or a request that blew
  up in the pipeline. It wears the game's real shell, sharing the head, header and footer
  components with the live layout rather than approximating them.

  No `app.js`: there is no LiveView here for it to drive.
  """
  use MiniLineageWeb, :html

  alias MiniLineage.Game.Version
  alias MiniLineageWeb.Layouts

  def render(template, assigns) do
    status = template |> String.split(".") |> hd()
    reason = Phoenix.Controller.status_message_from_template(template)

    assigns
    |> Map.put(:detail, detail(status, "#{status} #{reason}", assigns))
    |> Map.put(:message, message_for(status))
    |> page()
  end

  # What the `<pre>` is for. A release shows nothing here whatever went wrong — a stack trace names
  # modules, line numbers and arguments, and a player is not the audience for any of it. A debug
  # build shows the whole fault, because the alternative is reading "500 Internal Server Error" on
  # the page and then going to find the terminal it actually happened in.
  defp detail(status, short, assigns) do
    cond do
      not Version.debug_build?() ->
        nil

      # A mistyped URL is not a fault, and a trace for one would bury the real ones.
      status == "404" ->
        short

      # Phoenix hands the view what blew up. Rendered without one — a test, or a bare call — the
      # status line is all there is to say.
      is_map_key(assigns, :reason) ->
        Exception.format(kind(assigns), assigns.reason, stack(assigns))

      true ->
        short
    end
  end

  defp kind(assigns), do: Map.get(assigns, :kind, :error)
  defp stack(assigns), do: Map.get(assigns, :stack, [])

  defp message_for("404"), do: "That road leads nowhere."

  defp message_for(_status),
    do: "An unexpected error occurred on the server, please try again in a moment."

  defp page(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <Layouts.head scripts={false} />
        <title>Mini Lineage - Remastered</title>
      </head>
      <body>
        <div id="app">
          <div id="wrapper">
            <div id="header">
              <Layouts.site_header interactive?={false} />
            </div>

            <div id="content">
              <div id="main">
                <Controls.panel title="Error" heading>
                  <:header>
                    <div class="header-effects" id="effects"></div>
                  </:header>
                  <p>{@message}</p>
                  <pre :if={@detail} class="code-block">{@detail}</pre>
                  <%!-- The rule above it is what parts the way back from the page. A build that
                        showed the fault has a block sitting there already doing that. --%>
                  <p class={if @detail, do: "last", else: "last back"}>
                    <span class="muted">&laquo;</span> <a href={~p"/"}>Return to safer lands</a>
                  </p>
                </Controls.panel>

                <Layouts.footer />
              </div>
            </div>
          </div>
        </div>
      </body>
    </html>
    """
  end
end
