defmodule MiniLineageWeb.Layouts do
  @moduledoc """
  The page shell. Element ids and class names are load-bearing: the carried-over stylesheet keys
  off `#app`/`#wrapper`/`#header`/`#content`/`#main`/`.panel`. `#sidebar` and `#aside` are one kind
  of thing, a `.side` column, left of the main one and right of it.
  """
  use MiniLineageWeb, :html

  alias MiniLineage.Game.{Access, Format, Version}
  alias MiniLineageWeb.Paths

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
      href="https://fonts.googleapis.com/css2?family=Cinzel:wght@400;600;700&family=Inter:wght@400;500;600&family=Silkscreen:wght@400&display=swap"
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
  attr :character_id, :string, default: nil
  slot :inner_block, required: true

  # What the screen puts beside its panel rather than in it, in a column the page widens to hold.
  slot :aside

  def app(assigns) do
    ~H"""
    <div id="app">
      <%!-- Every keypress is a round trip, so the relay exists only while the sequence can do
            something; its own element, so arming mounts the hook rather than patching one. --%>
      <div :if={Access.konami?(@view)} id="konami-relay" phx-hook="KonamiRelay" hidden></div>
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
            <%!-- No wrapper of its own: `h2:first-child` drops the top margin, and an extra
                  element would qualify every screen's first heading even under an alert. --%>
            <Controls.panel
              title={@title}
              heading
              body_id="screen"
              phx-hook="PanelFocus"
              data-screen={@screen}
              data-started={to_string(@view.started)}
              data-dead={to_string(@view.dead)}
              data-ambushed={to_string(@view.ambushed)}
              data-battles={@view.counters.total_battles}
            >
              <:header>
                <div class="header-effects" id="effects" phx-hook="EffectTimers">
                  <.effect_icon :for={effect <- @view.effects} effect={effect} />
                </div>
              </:header>
              {render_slot(@inner_block)}
            </Controls.panel>

            <Layouts.footer />
          </div>

          <div :if={@aside != []} id="aside" class="side">{render_slot(@aside)}</div>
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
      data-remaining-ms={@effect.remaining_ms}
      title={@effect.tooltip}
    >
      <span class="effect-emoji">{@effect.emoji}</span>
      <span :if={@effect.remaining_ms} class="effect-timer" data-timer>{Format.countdown(
        @effect.remaining_ms
      )}</span>
    </span>
    """
  end

  attr :view, :map, required: true
  attr :character_id, :string, default: nil

  defp sidebar(assigns) do
    ~H"""
    <div id="sidebar" class="side" phx-hook="AnimatedValues">
      <Controls.panel title={@view.name} class="status-panel" body_class="rows">
        <%!-- Under the name and across both columns: "Elemental Summoner" overflows a value's. --%>
        <div class="stat-row calling">
          <span class="stat-value">
            {if @view.dead, do: "☠️", else: @view.race_emoji}
            <%!-- Flush against the anchor: a newline inside one renders as an underlined space. --%>
            <.link patch={Paths.for_character(@character_id, "game")}>{@view.class_name}</.link>
          </span>
        </div>

        <div class="stat-row">
          <span class="stat-label">Level</span>
          <span class="stat-value level"><Controls.figure key="level" value={@view.level} /></span>
        </div>

        <div class={"stat-row#{if @view.low_health, do: " danger"}"}>
          <span class="stat-label">HP</span>
          <Controls.bar
            id="hp-bar"
            kind={:hp}
            label="HP"
            key="hp"
            value={@view.health}
            of={@view.max_health}
            of_key="max-hp"
            of_id="status-max-hp"
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
            of_id="status-max-mp"
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
          />
        </div>

        <div class="stat-row">
          <span class="stat-label">Adena</span>
          <span class="stat-value adena">🪙
          <Controls.figure key="adena" value={@view.adena} format={:adena} /></span>
        </div>
      </Controls.panel>

      <%!-- Folds on a phone, open until the reader says otherwise: theirs on every screen, so kept. --%>
      <Controls.panel
        id="inventory"
        title="Inventory"
        class="inventory-panel"
        body_class="rows"
        collapsible
      >
        <div class="stat-row">
          <span class="stat-value" title="Equipped Armor">
            {@view.armor.emoji} <span class="item">{@view.armor.name}</span>
            <span :if={(@view.armor.regen || 0) > 0} class="regen">+<Controls.figure
              key="armor-regen"
              value={@view.armor.regen}
            /></span>
          </span>
        </div>
        <div class="stat-row">
          <span class="stat-value" title="Equipped Weapon">
            {@view.weapon.emoji} <span class="item">{@view.weapon.name}</span>
            <span :if={(@view.weapon.crit || 0) > 0} class="crit">+<Controls.figure
              key="weapon-crit"
              value={@view.weapon.crit}
            /></span>
          </span>
        </div>
      </Controls.panel>
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
              fill="currentColor"
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
      <span :if={!@commit_url} class={Version.build_class(@version)}>{@version}</span>
      &copy; 2005 &ndash; {@year}
    </div>
    """
  end
end
