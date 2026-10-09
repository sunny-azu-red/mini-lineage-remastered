defmodule MiniLineageWeb.Layouts do
  @moduledoc """
  The page shell. Element ids and class names are load-bearing: the stylesheet keys off
  `#app`/`#wrapper`/`#header`/`#content`/`#main`/`.panel`, and `#sidebar` is a `.side` column.
  """
  use MiniLineageWeb, :html

  alias MiniLineage.Game.{Access, Math, Version}

  # Rules §5 to §10 as L2's status window pairs them: the physical side, then the magical one.
  @combat [
    {"P. Atk.", :p_atk},
    {"M. Atk.", :m_atk},
    {"P. Def.", :p_def},
    {"M. Def.", :m_def},
    {"Accuracy", :accuracy},
    {"Evasion", :evasion},
    {"Critical", :critical},
    {"M. Critical", :magic_critical},
    {"Atk. Spd.", :atk_spd},
    {"Cast. Spd.", :cast_spd}
  ]
  @attributes ~w(str con dex int wit men)a

  embed_templates "layouts/*"

  @doc """
  The document head, shared with the error page, which has no LiveView, so the two cannot drift
  apart on fonts or stylesheets.
  """
  attr :scripts, :boolean, default: true

  def head(assigns) do
    ~H"""
    <meta charset="utf-8" />
    <%!-- LiveDebugger's config tag in dev, for its DevTools panel; nil, so nothing, elsewhere. --%>
    {Application.get_env(:live_debugger, :live_debugger_tags)}
    <meta
      name="viewport"
      content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=0"
    />
    <link rel="icon" href={~p"/favicon.ico"} type="image/x-icon" />
    <link rel="preconnect" href="https://fonts.googleapis.com" />
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
    <link
      href="https://fonts.googleapis.com/css2?family=Cinzel:wght@400;600;700&family=Inter:wght@400;500;600&display=swap"
      rel="stylesheet"
    />
    <link phx-track-static rel="stylesheet" href={~p"/assets/css/app.css"} />
    <script :if={@scripts} defer phx-track-static type="text/javascript" src={~p"/assets/js/app.js"}>
    </script>
    """
  end

  attr :title, :string, default: "Loading"
  attr :view, :map, required: true
  attr :screen, :string, required: true
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div id="app">
      <div id="wrapper">
        <div id="header">
          <Layouts.site_header />
        </div>

        <div id="content">
          <.sidebar :if={@view.started && Access.sidebar?(@screen)} view={@view} />

          <div id="main">
            <%!-- No wrapper of its own: `h2:first-child` drops the top margin, and an extra
                  element would qualify every screen's first heading even under an alert. --%>
            <Controls.panel
              title={@title}
              heading
              body_id="screen"
              phx-hook="PanelFocus"
              data-screen={@screen}
              data-started={to_string(@view.started)}
            >
              <:header>
                <div class="header-effects" id="effects">
                  <.effect_icon :for={effect <- @view.effects} effect={effect} />
                </div>
              </:header>
              {render_slot(@inner_block)}
            </Controls.panel>

            <Layouts.footer />
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :effect, :map, required: true

  defp effect_icon(assigns) do
    ~H"""
    <span
      class={"effect-icon effect-fade-in effect-#{@effect.type}"}
      data-effect-id={@effect.id}
      title={@effect.tooltip}
    >
      <span class="effect-emoji">{@effect.emoji}</span>
    </span>
    """
  end

  attr :view, :map, required: true

  defp sidebar(assigns) do
    ~H"""
    <div id="sidebar" class="side" phx-hook="AnimatedValues">
      <Controls.panel title={@view.name} class="status-panel" body_class="rows">
        <div class="stat-row">
          <span class="stat-label">Race</span>
          <span class="stat-value">
            {@view.race_emoji} {@view.class_name}
            <Controls.figure key="level" value={@view.level} />
          </span>
        </div>

        <div class="stat-row">
          <span class="stat-label">HP</span>
          <Controls.bar
            id="hp-bar"
            kind={:hp}
            label="HP"
            key="hp"
            value={@view.health}
            of={@view.max_health}
            of_key="max-hp"
          />
        </div>

        <div class="stat-row">
          <span class="stat-label">MP</span>
          <Controls.bar
            id="mp-bar"
            kind={:mp}
            label="MP"
            key="mp"
            value={@view.mp}
            of={@view.max_mp}
            of_key="max-mp"
          />
        </div>

        <div class="stat-row">
          <span class="stat-label">XP</span>
          <%!-- Past the last level there is no next one to fill toward, so the total is the figure. --%>
          <Controls.bar
            id="xp-bar"
            kind={:xp}
            label="XP"
            key="xp"
            value={if @view.is_max_level, do: @view.experience, else: @view.xp_current}
            of={unless @view.is_max_level, do: @view.xp_required}
            of_key="xp-required"
            wraps={@view.level}
            format={:short}
          />
        </div>
      </Controls.panel>

      <%!-- Folds at every width and starts folded, unless the reader has opened it. --%>
      <Controls.panel id="stats" title="Stats" class="folds" collapsible collapsed>
        <dl class="stat-grid">
          <div :for={{label, stat} <- combat()}>
            <dt class="stat-label">{label}</dt>
            <dd class="stat-value"><.stat stat={stat} value={@view.stats[stat]} /></dd>
          </div>
        </dl>
        <dl class="stat-grid attributes">
          <div :for={attr <- attributes()}>
            <dt class="stat-label">{String.upcase(to_string(attr))}</dt>
            <dd class="stat-value"><.stat stat={attr} value={@view.stats[attr]} /></dd>
          </div>
        </dl>
      </Controls.panel>

      <%!-- Folds on a phone, open until the reader says otherwise: theirs on every screen, so kept. --%>
      <Controls.panel
        id="inventory"
        title="Inventory"
        body_class="rows"
        collapsible
      >
        <div class="stat-row">
          <span class="stat-label">Adena</span>
          <span class="stat-value adena">🪙
          <Controls.figure key="adena" value={@view.adena} format={:short} /></span>
        </div>
      </Controls.panel>
    </div>
    """
  end

  defp combat, do: @combat
  defp attributes, do: @attributes

  attr :stat, :atom, required: true
  attr :value, :any, required: true

  # A chance is a percentage to a tenth, and moves only with DEX or WIT, so it is not counted.
  defp stat(%{stat: stat} = assigns) when stat in [:critical, :magic_critical] do
    ~H|<span id={"stat-#{String.replace(to_string(@stat), "_", "-")}"}>{Float.round(@value / 1, 1)}%</span>|
  end

  defp stat(assigns) do
    ~H|<Controls.figure key={String.replace(to_string(@stat), "_", "-")} value={Math.js_round(@value)} />|
  end

  @doc """
  The banner. `interactive?` is false on the error page, which has no LiveView, so there the
  banner is an ordinary link and the sound toggle, which nothing would drive, is left out.
  """
  attr :interactive?, :boolean, default: true

  def site_header(assigns) do
    ~H"""
    <div id="site-header">
      <.link
        patch={if @interactive?, do: ~p"/"}
        href={unless @interactive?, do: ~p"/"}
        id="header-link"
        class="header-clickable-area"
      >
        <svg class="header-emblem" xmlns="http://www.w3.org/2000/svg" viewBox="58 0 50 157">
          <g>
            <path
              fill="currentColor"
              d="M88.696 135.174c0 14.37 8.958 19.79 8.958 19.79-5.312-8.229-4.688-19.9-4.688-19.9l-.105-111.5c-.103-13.23 5-21.04 5-21.04-9.584 8.645-9.166 21.04-9.166 21.04v111.6m-18.999-.09c0 14.38-8.96 19.79-8.96 19.79 5.313-8.23 4.689-19.9 4.689-19.9l.104-111.5c.104-13.23-5-21.04-5-21.04 9.584 8.646 9.167 21.04 9.167 21.04v111.6"
            />
          </g>
        </svg>
        <span class="header-title">Mini Lineage</span>
        <span class="header-subtitle">Remastered</span>
      </.link>
      <%!-- Outside the anchor, so clicking it never also navigates. Ignored by patches: the hook
            draws the reader's state over the template's. --%>
      <button
        :if={@interactive?}
        id="sound-toggle"
        type="button"
        phx-hook="SoundToggle"
        phx-update="ignore"
        class="sound-toggle-btn"
      >
        🔊
      </button>
    </div>
    """
  end

  def footer(assigns) do
    version = Version.current()

    assigns =
      assign(assigns,
        year: Date.utc_today().year,
        version: version,
        commit_url: Version.commit_url(version)
      )

    ~H"""
    <div id="copyright">
      <a
        :if={@commit_url}
        href={@commit_url}
        target="_blank"
        rel="noopener noreferrer"
        class="version-link"
      >{@version}</a>
      <span :if={!@commit_url} class={Version.build_class(@version)}>{@version}</span>
      &copy; 2005 &ndash; {@year}
    </div>
    """
  end
end
