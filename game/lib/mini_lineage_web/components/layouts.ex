defmodule MiniLineageWeb.Layouts do
  @moduledoc """
  The page shell. Element ids and class names are load-bearing: the carried-over stylesheet keys
  off `#app`/`#wrapper`/`#header`/`#content`/`#sidebar`/`#main`/`.panel`.
  """
  use MiniLineageWeb, :html

  alias MiniLineage.Game.Format
  alias MiniLineageWeb.{Paths, Screens}

  embed_templates "layouts/*"

  attr :flash, :map, required: true
  attr :title, :string, default: "Loading"
  attr :view, :map, required: true
  attr :screen, :string, required: true
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div id="app">
      <div id="wrapper">
        <div id="header">
          <.site_header />
        </div>

        <div id="content">
          <.sidebar :if={@view.started && Screens.sidebar?(@screen)} view={@view} />

          <div id="main">
            <div class="panel">
              <div class="panel-header flex">
                <span class="header-name">{@title}</span>
                <div class="header-effects" id="effects">
                  <.effect_icon :for={effect <- effects_of(@view)} effect={effect} />
                </div>
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
      <span :if={@effect.remaining_ms} class="effect-timer">{effect_timer(@effect.remaining_ms)}</span>
    </span>
    """
  end

  defp effect_timer(remaining_ms) do
    seconds = max(0, ceil(remaining_ms / 1000))

    if seconds >= 60, do: "#{div(seconds, 60)}m", else: Integer.to_string(seconds)
  end

  attr :view, :map, required: true

  defp sidebar(assigns) do
    ~H"""
    <div id="sidebar">
      <div class="panel status-panel">
        <div class="panel-header flex">
          <span class="header-name">{@view.name}</span>
        </div>
        <div class="panel-body small">
          <div class="stat-row">
            <span class="stat-label">Race</span>
            <span class="stat-value">
              {if @view.dead, do: "☠️", else: @view.race_emoji}
              <.link patch={Paths.for_screen("character")}>
                {@view.race_label} level {Format.number(@view.level)}
              </.link>
            </span>
          </div>

          <div class={"stat-row bar#{if @view.low_health, do: " danger"}"}>
            <span class="stat-label">HP</span>
            <div class="bar-track" id="hp-track">
              <div class="bar hp-bar" id="hp-bar" style={"width:#{@view.hp_percent}%"}></div>
              <span class="bar-text">
                <span class="animate-val">{Format.number(@view.health)}</span>/<span id="status-max-hp">{Format.number(
                  @view.max_health
                )}</span>
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
                <span class="animate-val">
                  {Format.number(if @view.is_max_level, do: @view.experience, else: @view.xp_current)}
                </span><span :if={!@view.is_max_level}>/{Format.number(@view.xp_required)}</span>
              </span>
            </div>
          </div>

          <div class="stat-row">
            <span class="stat-label">Adena</span>
            <span class="stat-value gold">🪙
            <span class="animate-adena">{Format.adena(@view.adena)}</span></span>
          </div>
        </div>
      </div>

      <div class="panel inventory-panel">
        <div class="panel-header">Inventory</div>
        <div class="panel-body small">
          <div class="stat-row">
            <span class="stat-value" title="Equipped Armor">
              {@view.armor.emoji} {@view.armor.name}
              <span :if={(@view.armor.regen || 0) > 0} class="heal">+{@view.armor.regen}</span>
            </span>
          </div>
          <div class="stat-row">
            <span class="stat-value" title="Equipped Weapon">
              {@view.weapon.emoji} {@view.weapon.name}
              <span :if={(@view.weapon.crit || 0) > 0} class="crit">{@view.weapon.crit}%</span>
            </span>
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
