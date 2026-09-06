defmodule MiniLineageWeb.ErrorHTML do
  @moduledoc """
  Errors Phoenix itself raises, before a LiveView ever mounts — a bad URL, a request that blew up
  in the pipeline. Rendered in the game's own shell rather than as bare text, and the reason is
  shown only in a non-release build.
  """
  use MiniLineageWeb, :html

  alias MiniLineage.Game.Version

  def render(template, assigns) do
    status = template |> String.split(".") |> hd()
    reason = Phoenix.Controller.status_message_from_template(template)

    assigns =
      assigns
      |> Map.put(:status, status)
      |> Map.put(:detail, unless(Version.release?(Version.current()), do: "#{status} #{reason}"))
      |> Map.put(:message, message_for(status, reason))

    page(assigns)
  end

  defp message_for("404", _reason), do: "That road leads nowhere."

  defp message_for(_status, _reason),
    do: "An unexpected error occurred on the server, please try again in a moment."

  defp page(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <title>Mini Lineage - Remastered</title>
        <link rel="icon" href={~p"/favicon.ico"} type="image/x-icon" />
        <link rel="stylesheet" href={~p"/assets/css/app.css"} />
      </head>
      <body>
        <div id="app">
          <div id="wrapper">
            <div id="content">
              <div id="main">
                <div class="panel">
                  <div class="panel-header flex">
                    <span class="header-name">Something Went Wrong</span>
                  </div>
                  <div class="panel-body">
                    <p>{@message}</p>
                    <pre :if={@detail} class="code-block">{@detail}</pre>
                    <p class="last back"><a href={~p"/"}>Return to safer lands</a></p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </body>
    </html>
    """
  end
end
