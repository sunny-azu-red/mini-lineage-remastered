defmodule MiniLineageWeb.Layouts do
  @moduledoc """
  The page shell. Element ids and class names are load-bearing: the carried-over stylesheet keys
  off `#app`/`#wrapper`/`#header`/`#content`/`#sidebar`/`#main`/`.panel`.
  """
  use MiniLineageWeb, :html

  alias MiniLineage.Game.{Access, Format, Version}
  alias MiniLineageWeb.Paths

  embed_templates "layouts/*"

  @doc """
  The document head. Shared with the error page, which is rendered without a LiveView — so the
  two cannot drift apart on fonts or stylesheets the way they already did once.
  """
  attr :scripts, :boolean, default: true

  def head(assigns) do
    ~H"""
    <meta charset="utf-8" />
    <meta
      name="viewport"
      content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=0"
    />
    <link rel="icon" href={~p"/favicon.ico"} type="image/x-icon" />
    <link rel="preconnect" href="https://fonts.googleapis.com" />
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
    <link
      href="https://fonts.googleapis.com/css2?family=Cinzel:wght@400;600;700&family=Inter:wght@400;500;600&family=Silkscreen:wght@400&display=swap"
      rel="stylesheet"
    />
    <link phx-track-static rel="stylesheet" href={~p"/assets/css/app.css"} />
    <script :if={@scripts} defer phx-track-static type="text/javascript" src={~p"/assets/js/app.js"}>
    </script>
    """
  end

  attr :flash, :map, required: true
  attr :title, :string, default: "Loading"
  attr :view, :map, required: true
  attr :screen, :string, required: true
  attr :character_id, :string, default: nil
  slot :inner_block, required: true
  # What belongs to the screen but not inside its panel. The Chronicle is the only one: a run's
  # fights are longer than everything else on the page put together, and in the panel they crowd
  # out what the panel is named for.
  slot :aside

  def app(assigns) do
    ~H"""
    <div id="app" phx-hook="KonamiRelay">
      <div id="wrapper">
        <div id="header">
          <Layouts.site_header />
        </div>

        <div id="content">
          <.sidebar
            :if={@view.started && Access.sidebar?(@screen)}
            view={@view}
            character_id={@character_id}
          />

          <div id="main">
            <div class="panel">
              <div class="panel-header flex">
                <h1 class="header-name">{@title}</h1>
                <div class="header-effects" id="effects" phx-hook="EffectTimers">
                  <.effect_icon :for={effect <- effects_of(@view)} effect={effect} />
                </div>
              </div>

              <%!-- No wrapper of its own: `h2:first-child` drops its top margin, and an extra
                    element would qualify every screen's first heading even under an alert. The
                    data attributes mirror live state, so a browser test need not scrape prose. --%>
              <div
                class="panel-body"
                id="screen"
                phx-hook="PanelFocus"
                data-screen={@screen}
                data-started={to_string(@view.started)}
                data-dead={to_string(@view[:dead] || false)}
                data-ambushed={to_string(@view[:ambushed] || false)}
                data-level={@view[:level]}
                data-health={@view[:health]}
                data-max-health={@view[:max_health]}
                data-adena={@view[:adena]}
                data-battles={@view[:counters] && @view.counters.total_battles}
              >
                {render_slot(@inner_block)}
              </div>
            </div>

            {render_slot(@aside)}

            <Layouts.footer />
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp effects_of(%{started: true, effects: effects}), do: effects
  defp effects_of(_view), do: []

  attr :effect, :map, required: true

  defp effect_icon(assigns) do
    ~H"""
    <span
      class={"effect-icon effect-fade-in effect-#{@effect.type}"}
      data-effect-id={@effect.id}
      data-label={@effect.label}
      data-remaining-ms={@effect.remaining_ms}
      title={@effect.tooltip}
    >
      <span class="effect-emoji">{@effect.emoji}</span>
      <span :if={@effect.remaining_ms} class="effect-timer">{Format.countdown(@effect.remaining_ms)}</span>
    </span>
    """
  end

  attr :view, :map, required: true
  attr :character_id, :string, default: nil

  defp sidebar(assigns) do
    assigns = assign(assigns, level: Format.number(assigns.view.level))

    ~H"""
    <div id="sidebar" phx-hook="AnimatedValues">
      <div class="panel status-panel">
        <div class="panel-header flex">
          <span class="header-name">{@view.name}</span>
        </div>
        <div class="panel-body small">
          <div class="stat-row">
            <span class="stat-label">Race</span>
            <span class="stat-value">
              {if @view.dead, do: "☠️", else: @view.race_emoji}
              <%!-- Flush against the anchor: a newline inside one renders as a space, and the
                    underline runs through it. --%>
              <.link patch={Paths.for_character(@character_id, "game")}>{@view.race_label} level
              <span data-key="level" data-value={@view.level}>{@level}</span></.link>
            </span>
          </div>

          <div class={"stat-row bar#{if @view.low_health, do: " danger"}"}>
            <span class="stat-label">HP</span>
            <div class="bar-track" id="hp-track">
              <div class="bar hp-bar" id="hp-bar" style={"width:#{@view.hp_percent}%"}></div>
              <span class="bar-text">
                <span data-key="hp" data-value={@view.health}>{Format.number(@view.health)}</span>/<span
                  id="status-max-hp"
                  data-key="max-hp"
                  data-value={@view.max_health}
                >{Format.number(@view.max_health)}</span>
              </span>
            </div>
          </div>

          <div class="stat-row bar">
            <span class="stat-label">XP</span>
            <div class="bar-track">
              <div
                class="bar xp-bar"
                id="xp-bar"
                style={"width:#{if @view.is_max_level, do: 100, else: @view.xp_percent}%"}
                data-level={@view.level}
              >
              </div>
              <span class="bar-text">
                <span
                  data-key="xp"
                  data-value={if @view.is_max_level, do: @view.experience, else: @view.xp_current}
                >{Format.number(if @view.is_max_level, do: @view.experience, else: @view.xp_current)}</span><span :if={
                  !@view.is_max_level
                }>/<span data-key="xp-required" data-value={@view.xp_required}>{Format.number(
                  @view.xp_required
                )}</span></span>
              </span>
            </div>
          </div>

          <div class="stat-row">
            <span class="stat-label">Adena</span>
            <span class="stat-value gold">🪙
            <span data-key="adena" data-format="adena" data-value={@view.adena}>{Format.adena(
              @view.adena
            )}</span></span>
          </div>
        </div>
      </div>

      <div class="panel inventory-panel">
        <div class="panel-header flex">
          <span class="header-name">Inventory</span>
        </div>
        <div class="panel-body small">
          <div class="stat-row">
            <span class="stat-value" title="Equipped Armor">
              {@view.armor.emoji} {@view.armor.name}
              <span :if={(@view.armor.regen || 0) > 0} class="heal">+<span
                data-key="armor-regen"
                data-value={@view.armor.regen}
              >{@view.armor.regen}</span></span>
            </span>
          </div>
          <div class="stat-row">
            <span class="stat-value" title="Equipped Weapon">
              {@view.weapon.emoji} {@view.weapon.name}
              <span :if={(@view.weapon.crit || 0) > 0} class="crit"><span
                data-key="weapon-crit"
                data-value={@view.weapon.crit}
              >{@view.weapon.crit}</span>%</span>
            </span>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  The banner. `interactive?` is false on the error page, which has no LiveView — so there the
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
              fill="#c9a84c"
              d="M88.696 135.174c0 14.37 8.958 19.79 8.958 19.79-5.312-8.229-4.688-19.9-4.688-19.9l-.105-111.5c-.103-13.23 5-21.04 5-21.04-9.584 8.645-9.166 21.04-9.166 21.04v111.6m-18.999-.09c0 14.38-8.96 19.79-8.96 19.79 5.313-8.23 4.689-19.9 4.689-19.9l.104-111.5c.104-13.23-5-21.04-5-21.04 9.584 8.646 9.167 21.04 9.167 21.04v111.6"
            />
          </g>
        </svg>
        <span class="header-title">Mini Lineage</span>
        <span class="header-subtitle">Remastered</span>
      </.link>
      <%!-- Outside the anchor, so clicking it never also navigates. --%>
      <button
        :if={@interactive?}
        id="sound-toggle"
        type="button"
        phx-hook="SoundToggle"
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
      <span :if={!@commit_url} class="version-debug">{@version}</span>
      &copy; 2005 &ndash; {@year}
    </div>
    """
  end
end
