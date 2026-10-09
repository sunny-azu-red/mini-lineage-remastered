defmodule MiniLineageWeb.Controls do
  @moduledoc """
  What every screen reaches for and no screen owns: the panel, the button and the choice it acts
  on, the table, the alerts, the fault, the figure and the bar. `raw/1` renders flashes, which
  the server composes from the template tables — never from anything a player typed.
  """
  use MiniLineageWeb, :html

  alias MiniLineage.Game.{Format, Math}

  # ------------------------------------------------------------------- panels

  @doc """
  The card every part of the game is drawn on. `id` names the PANEL, for its hook; every other
  attribute lands on the BODY. A hook only when something moves, so the error page, with no
  LiveView, renders one that asks for no JavaScript.
  """
  attr :id, :string, default: nil
  attr :title, :string, required: true
  # An emoji set before the title as one line of text.
  attr :icon, :string, default: nil

  attr :class, :any, default: nil
  attr :body_class, :any, default: nil

  # Folds wherever the stylesheet's `--folds` is not 0: a layout may keep a panel open where there
  # is room, and the hook reads the answer rather than a breakpoint.
  attr :collapsible, :boolean, default: false
  # Where a collapsible panel starts, until the reader's kept fold says otherwise.
  attr :collapsed, :boolean, default: false
  attr :rest, :global
  slot :header
  slot :inner_block, required: true

  def panel(assigns) do
    ~H"""
    <div
      id={@id}
      class={classes(["panel", @class])}
      phx-hook={if @collapsible, do: "Panel"}
    >
      <%!-- The whole band is the control: a title you have to hit exactly is worse than none. A
            button's contents are never read as a heading, so the h2 wraps it. --%>
      <h2 :if={@collapsible} class="panel-heading">
        <button
          type="button"
          class="panel-header flex panel-toggle"
          aria-expanded={to_string(!@collapsed)}
        >
          <span class="header-name">{label(@icon, @title)}</span>
          {render_slot(@header)}
          <span class="panel-arrow" aria-hidden="true"></span>
        </button>
      </h2>
      <div :if={!@collapsible} class="panel-header flex">
        <h2 class="header-name">{label(@icon, @title)}</h2>
        {render_slot(@header)}
      </div>

      <div class={classes(["panel-body", @body_class])} {@rest}>
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  defp label(nil, title), do: title
  defp label(icon, title), do: "#{icon} #{title}"

  # HEEx renders `class` whatever its value, so it is built first.
  defp classes(parts), do: parts |> Enum.reject(&(&1 in [nil, false, ""])) |> Enum.join(" ")

  # ----------------------------------------------------------------- buttons

  @doc """
  Every `.btn` in the game: a `<button>`, because it does something. One that goes somewhere is a
  link, and comes back as a `patch` option when a screen first needs one.
  """
  attr :type, :string, default: "button"
  attr :variant, :atom, default: :primary, values: [:primary, :secondary]
  attr :class, :string, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def button(assigns) do
    variant = if assigns.variant == :secondary, do: "btn-secondary"
    assigns = assign(assigns, classes: classes(["btn", variant, assigns.class]))

    ~H"""
    <button type={@type} class={@classes} {@rest}>{render_slot(@inner_block)}</button>
    """
  end

  @doc """
  A choice and the button that acts on it, which is how a player moves: the town's destinations, a
  Gatekeeper's routes. Until the PLAYER picks, the button reads `default_label` in the quieter look;
  a `placeholder` is the empty choice, which the event reads as going back.
  """
  # LiveView restores a form's pick after a reconnect only when the form has an id.
  attr :id, :string, required: true
  attr :event, :string, required: true
  attr :name, :string, required: true
  attr :options, :list, required: true
  attr :placeholder, :string, default: nil
  attr :picked, :string, default: nil
  attr :default_label, :string, required: true
  attr :active_label, :string, required: true
  attr :default_variant, :atom, default: :secondary

  def select_action(assigns) do
    chosen? = chosen?(assigns.picked)

    assigns =
      assign(assigns,
        label: if(chosen?, do: assigns.active_label, else: assigns.default_label),
        variant: if(chosen?, do: :primary, else: assigns.default_variant)
      )

    ~H"""
    <form id={@id} phx-submit={@event} phx-change="pick">
      <div class="form-row">
        <%!-- `selected` explicitly: relabelling the button re-renders the options, and would
              otherwise drop the player's choice. --%>
        <select name={@name} class="form-select">
          <option :if={@placeholder} value="" selected={!chosen?(@picked)}>{@placeholder}</option>
          <option
            :for={option <- @options}
            value={option.value}
            disabled={option[:disabled?]}
            selected={@picked == option.value}
          >
            {option.label}
          </option>
        </select>
        <.button type="submit" variant={@variant}>{@label}</.button>
      </div>
    </form>
    """
  end

  defp chosen?(picked), do: picked not in [nil, ""]

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

  # ------------------------------------------------------------------ faults

  attr :detail, :string, default: nil

  @doc """
  What a fault may show, on both error pages: the game's own screen and the one Phoenix draws.
  Withholding the trace is the caller's call.
  """
  def fault(assigns) do
    ~H"""
    <pre :if={@detail} class="code-block">{@detail}</pre>
    """
  end

  # ----------------------------------------------------------------- figures

  attr :key, :string, required: true
  attr :value, :integer, required: true
  attr :format, :atom, default: :number, values: [:number, :short, :percent]
  attr :rest, :global

  @doc """
  A figure the player can watch change, which `AnimatedValues` counts from the value it last saw.
  The value is written once, so what the count heads for and the text it lands on cannot differ.
  """
  def figure(assigns) do
    assigns = assign(assigns, text: figure_text(assigns.format, assigns.value))

    ~H|<span data-key={@key} data-value={@value} data-format={@format != :number && @format} {@rest}>{@text}</span>|
  end

  defp figure_text(:short, value), do: Format.short(value)
  defp figure_text(:percent, value), do: Format.percent(value)
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
  # A change here means the bar went round, not back: `AnimatedValues` refills it from empty.
  attr :wraps, :any, default: nil
  # How both figures are written; a screen reader is always told them in full. `:percent` writes
  # one figure instead, the share of `of` in hundredths, keyed `<key>-percent`.
  attr :format, :atom, default: :number, values: [:number, :short, :percent]

  @doc """
  A figure against its cap, as a bar filled to it. Its width, its figures and what a screen reader
  is told are all written from `value` and `of`, so none of them can disagree.
  """
  def bar(assigns) do
    %{value: value, of: of, label: label} = assigns

    assigns =
      assign(assigns,
        width: if(of, do: Math.percentage(value, of, 1), else: 100),
        percent?: assigns.format == :percent and of != nil,
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
      <span class="bar-label" aria-hidden="true">{@label}</span>
      <span :if={@percent?} class="bar-text"><.figure
        key={"#{@key}-percent"}
        value={Math.hundredths(@value, @of)}
        format={:percent}
      /></span>
      <span :if={!@percent?} class="bar-text" phx-no-format><.figure key={@key} value={@value} format={@format} /><span :if={@of}>&nbsp;/&nbsp;<.figure key={@of_key} value={@of} format={@format} /></span></span>
    </div>
    """
  end
end
