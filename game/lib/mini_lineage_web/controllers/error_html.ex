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
    |> Map.put(:detail, unless(Version.release?(Version.current()), do: "#{status} #{reason}"))
    |> Map.put(:message, message_for(status))
    |> page()
  end

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
                <div class="panel">
                  <div class="panel-header flex">
                    <span class="header-name">Error</span>
                    <div class="header-effects" id="effects"></div>
                  </div>

                  <div class="panel-body">
                    <p>{@message}</p>
                    <pre :if={@detail} class="code-block">{@detail}</pre>
                    <p class="last back"><a href={~p"/"}>Return to safer lands</a></p>
                  </div>
                </div>

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
