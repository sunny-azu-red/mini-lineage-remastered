defmodule MiniLineageWeb.Controls do
  @moduledoc """
  What every screen reaches for and no screen owns: the panel, the button, the table, the alerts,
  the way back, the figure and the bar. `raw/1` renders flashes, which the server composes from the
  template tables — never from anything a player typed.
  """
  use MiniLineageWeb, :html

  alias MiniLineage.Game.{Format, Math}
  alias MiniLineageWeb.Paths

  # ------------------------------------------------------------------- panels

  @doc """
  The card every part of the game is drawn on. `id` names the PANEL, for its hook; `body_id` and
  every other attribute land on the BODY, which a screen is addressed by. A hook only when something
  moves, so the error page, with no LiveView, renders one that asks for no JavaScript.
  """
  attr :id, :string, default: nil
  attr :body_id, :string, default: nil
  attr :title, :string, required: true

  # The screen the panel names takes the page's one h1; every other panel titles itself with a span.
  attr :heading, :boolean, default: false
  attr :class, :any, default: nil
  attr :body_class, :any, default: nil

  # Folds wherever the stylesheet's `--folds` is not 0: a layout may keep a panel open where there
  # is room, and the hook reads the answer rather than a breakpoint.
  attr :collapsible, :boolean, default: false
  # Where a collapsible panel starts, until the reader's kept fold says otherwise.
  attr :collapsed, :boolean, default: false
  # Whether the reader's last fold is kept for the next mount. False starts every visit afresh.
  attr :remember, :boolean, default: true
  attr :rest, :global
  slot :header
  slot :inner_block, required: true

  def panel(assigns) do
    ~H"""
    <div
      id={@id}
      class={classes(["panel", @class])}
      phx-hook={if @collapsible, do: "Panel"}
      data-remember={if !@remember, do: "false"}
    >
      <%!-- The whole band is the control: a title you have to hit exactly is worse than none. --%>
      <.dynamic_tag
        tag_name={if @collapsible, do: "button", else: "div"}
        class={classes(["panel-header flex", @collapsible && "panel-toggle"])}
        {folds(@collapsible, @collapsed)}
      >
        <h1 :if={@heading} class="header-name">{@title}</h1>
        <span :if={!@heading} class="header-name">{@title}</span>
        {render_slot(@header)}
        <span :if={@collapsible} class="panel-arrow" aria-hidden="true"></span>
      </.dynamic_tag>

      <div id={@body_id} class={classes(["panel-body", @body_class])} {@rest}>
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  # HEEx renders `class` whatever its value, so it is built first.
  defp classes(parts), do: parts |> Enum.reject(&(&1 in [nil, false, ""])) |> Enum.join(" ")

  # A BUTTON rather than a link: this goes nowhere, and Space activates a button but scrolls a link.
  # `aria-expanded` IS the state the arrow turns off, so the mark and the screen reader agree.
  defp folds(false, _collapsed), do: []
  defp folds(true, collapsed), do: [type: "button", "aria-expanded": to_string(!collapsed)]

  # ----------------------------------------------------------------- buttons

  @doc """
  Every `.btn` in the game. With `patch` it is a link, because it goes somewhere and a reader may
  want it in a new tab; without, a `<button>`, because it does something. How it looks never
  decides the element.
  """
  attr :patch, :string, default: nil
  attr :type, :string, default: "button"
  attr :class, :string, default: nil
  attr :rest, :global, include: ~w(disabled form name value)
  slot :inner_block, required: true

  def button(assigns) do
    assigns = assign(assigns, classes: classes(["btn", assigns.class]))

    ~H"""
    <.link :if={@patch} patch={@patch} class={@classes} {@rest}>{render_slot(@inner_block)}</.link>
    <button :if={!@patch} type={@type} class={@classes} {@rest}>{render_slot(@inner_block)}</button>
    """
  end

  # ------------------------------------------------------------------ tables

  @doc "Every table in the game. The rows are the caller's `<tbody>`."
  attr :id, :string, required: true
  # Lands on the `<table>`.
  attr :rest, :global

  slot :col, required: true do
    attr :class, :string
    attr :title, :string
  end

  slot :inner_block, required: true

  def data_table(assigns) do
    ~H"""
    <div class="table-container">
      <table id={@id} class="data-table" {@rest}>
        <thead>
          <tr>
            <th :for={col <- @col} title={col[:title]} {column(col)}>{render_slot(col)}</th>
          </tr>
        </thead>
        {render_slot(@inner_block)}
      </table>
    </div>
    """
  end

  # Spread, so a column with no class prints no `class=""`.
  defp column(col), do: if(col[:class], do: [class: col[:class]], else: [])

  # ------------------------------------------------------------------ alerts

  @doc """
  Every alert in the game. None is dismissible: what it says belongs to the screen it stands on.
  """
  attr :kind, :atom, required: true, values: [:info, :danger]
  attr :rest, :global
  slot :inner_block, required: true

  def alert(assigns) do
    ~H|<div class={"alert alert-#{@kind}"} {@rest}>{render_slot(@inner_block)}</div>|
  end

  @doc "The result of an action, a refusal included. It disappears the moment you leave the screen."
  attr :flash, :map, required: true

  def flash_alert(assigns) do
    ~H"""
    <.alert id="flash" kind={@flash.type}>{raw(@flash.text)}</.alert>
    """
  end

  # --------------------------------------------------------------- the way back

  attr :started, :boolean, required: true
  attr :class, :string, default: "last back"

  def back_link(assigns) do
    ~H"""
    <.back
      href={Paths.for_screen(if(@started, do: "home", else: "start"))}
      text={if @started, do: "Continue your journey", else: "Go back to game start"}
      class={@class}
    />
    """
  end

  attr :href, :string, required: true
  attr :text, :string, required: true
  attr :class, :string, default: "last back"
  # False where no LiveView is behind the page, which a patch would need.
  attr :interactive?, :boolean, default: true

  # The anchor sits flush against its text. The mark sits OUTSIDE it, so a click lands on the
  # words, and is muted because it says which way this goes and nothing else.
  defp back(assigns) do
    ~H"""
    <p class={@class}>
      <span class="muted">&laquo;</span>
      <.link
        patch={if @interactive?, do: @href}
        href={unless @interactive?, do: @href}
      >{@text}</.link>
    </p>
    """
  end

  attr :detail, :string, default: nil
  attr :interactive?, :boolean, default: true

  @doc """
  What a fault may show, and the way out of it, on both error pages: the game's own screen and the
  one Phoenix draws, which has no LiveView behind it. Withholding the trace is the caller's call.
  """
  def fault(assigns) do
    ~H"""
    <pre :if={@detail} class="code-block">{@detail}</pre>
    <%!-- `/` is whichever the run is in, the town or game start. A fault's block parts the way back
          already; without one, the rule does. --%>
    <.back
      href={Paths.for_screen("home")}
      text="Return to safer lands"
      class={if @detail, do: "last", else: "last back"}
      interactive?={@interactive?}
    />
    """
  end

  # ----------------------------------------------------------------- figures

  attr :key, :string, required: true
  attr :value, :integer, required: true
  attr :format, :atom, default: :number, values: [:number, :short]
  attr :rest, :global

  @doc """
  A figure the player can watch change, which `AnimatedValues` counts from the value it last saw.
  The value is written once, so what the count heads for and the text it lands on cannot differ.
  """
  def figure(assigns) do
    assigns = assign(assigns, text: figure_text(assigns.format, assigns.value))

    ~H|<span data-key={@key} data-value={@value} data-format={@format == :short && "short"} {@rest}>{@text}</span>|
  end

  defp figure_text(:short, value), do: Format.short(value)
  defp figure_text(:number, value), do: Format.number(value)

  # -------------------------------------------------------------------- bars

  attr :id, :string, required: true
  attr :kind, :atom, required: true, values: [:hp, :mp, :xp]
  attr :label, :string, required: true
  attr :key, :string, required: true
  attr :value, :integer, required: true
  # No cap is a figure in a full track, which is what XP becomes at the last level.
  attr :of, :integer, default: nil
  attr :of_key, :string, default: nil
  attr :of_id, :string, default: nil
  # A change here means the bar went round, not back: `AnimatedValues` refills it from empty.
  attr :wraps, :any, default: nil
  # How both figures are written; a screen reader is always told them in full.
  attr :format, :atom, default: :number, values: [:number, :short]

  @doc """
  A figure against its cap, as a bar filled to it. Its width, its figures and what a screen reader
  is told are all written from `value` and `of`, so none of them can disagree.
  """
  def bar(assigns) do
    %{value: value, of: of, label: label} = assigns

    assigns =
      assign(assigns,
        width: if(of, do: Math.percentage(value, of, 1), else: 100),
        role: if(assigns.kind == :xp, do: "progressbar", else: "meter"),
        spoken:
          if(of,
            do: "#{Format.number(value)} of #{Format.number(of)} #{label}",
            else: "#{Format.number(value)} #{label}"
          )
      )

    # `class` is the hook's once mounted: a patch rewriting it cut the shimmer short mid-sweep.
    ~H"""
    <div
      class="bar-track"
      role={@role}
      aria-label={@label}
      aria-valuemin="0"
      aria-valuenow={@value}
      aria-valuemax={@of || @value}
      aria-valuetext={@spoken}
    >
      <div
        id={@id}
        class={"bar #{@kind}-bar"}
        style={"width:#{@width}%"}
        data-wraps={@wraps}
        phx-mounted={JS.ignore_attributes(["class"])}
      >
      </div>
      <span class="bar-text" phx-no-format><.figure key={@key} value={@value} format={@format} /><span :if={@of}>&nbsp;/&nbsp;<.figure key={@of_key} value={@of} id={@of_id} format={@format} /></span></span>
    </div>
    """
  end
end
