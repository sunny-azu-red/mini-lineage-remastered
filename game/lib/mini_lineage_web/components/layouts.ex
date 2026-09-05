defmodule MiniLineageWeb.Layouts do
  @moduledoc """
  The page shell. Element ids and class names are load-bearing: the carried-over stylesheet keys
  off `#app`/`#wrapper`/`#header`/`#content`/`#main`/`.panel`.
  """
  use MiniLineageWeb, :html

  embed_templates "layouts/*"

  attr :flash, :map, required: true
  attr :title, :string, default: "Loading"
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div id="app">
      <div id="wrapper">
        <div id="header">
          <.site_header />
        </div>

        <div id="content">
          <div id="main">
            <div class="panel">
              <div class="panel-header flex">
                <span class="header-name">{@title}</span>
                <div class="header-effects" id="effects"></div>
              </div>

              <div class="panel-body">
                {render_slot(@inner_block)}
              </div>
            </div>

            <.footer />
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp site_header(assigns) do
    ~H"""
    <div id="site-header">
      <a href={~p"/"} id="header-link" class="header-clickable-area">
        <svg class="header-emblem" xmlns="http://www.w3.org/2000/svg" viewBox="58 0 50 157">
          <g>
            <path
              fill="#c9a84c"
              d="M88.696 135.174c0 14.37 8.958 19.79 8.958 19.79-5.312-8.229-4.688-19.9-4.688-19.9l-.105-111.5c-.103-13.23 5-21.04 5-21.04-9.584 8.645-9.166 21.04-9.166 21.04v111.6m-18.999-.09c0 14.38-8.96 19.79-8.96 19.79 5.313-8.23 4.689-19.9 4.689-19.9l.104-111.5c.104-13.23-5-21.04-5-21.04 9.584 8.646 9.167 21.04 9.167 21.04v111.6"
            />
          </g>
        </svg>
        <span class="header-title">Mini Lineage</span>
        <span class="header-subtitle">Remastered</span>
      </a>
    </div>
    """
  end

  defp footer(assigns) do
    assigns = assign(assigns, year: Date.utc_today().year)

    ~H"""
    <div id="copyright">
      <span class="version-debug">⚡ development</span> &copy; 2005 &ndash; {@year}
    </div>
    """
  end
end
