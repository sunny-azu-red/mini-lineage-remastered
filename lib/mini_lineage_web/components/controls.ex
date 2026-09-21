defmodule MiniLineageWeb.Controls do
  @moduledoc """
  What every screen reaches for and no screen owns: the panel card itself, the alerts, the one
  action form behind Town and the shops, the way back, and a stamp on the reader's own clock.

  `raw/1` appears wherever a narrative or flash is rendered. Those strings are always composed by
  the server from the template tables — never from anything a player typed.
  """
  use MiniLineageWeb, :html

  alias MiniLineage.Game.Format
  alias MiniLineageWeb.Paths

  # ------------------------------------------------------------------- panels

  @doc """
  The card every part of the game is drawn on: a header band and a body under it.

  `id` names the PANEL and is what its hook needs; `body_id` and every other attribute given here —
  the body's own hook, its data attributes — land on the BODY, which is what a screen is addressed
  by. A panel carries a hook only when something about it moves, so the error page, which has no
  LiveView behind it, renders one that cannot ask for JavaScript.
  """
  attr :id, :string, default: nil
  # The BODY's own id, kept apart from the panel's: the panel's is what the hook needs, and the
  # body's is what the screen is addressed by.
  attr :body_id, :string, default: nil
  attr :title, :string, required: true

  # The screen the panel names takes the page's one h1; every other panel titles itself with a span.
  attr :heading, :boolean, default: false
  attr :class, :any, default: nil
  attr :body_class, :any, default: nil
  attr :collapsible, :boolean, default: false
  # Where a collapsible panel starts. The reader's own toggling outlives a patch but not a mount.
  attr :collapsed, :boolean, default: false
  # Pixels. Given one, the BODY scrolls — so the bar sits against the panel's edge rather than
  # inside the body's padding, and the page is the same height however much is in it.
  attr :max_height, :integer, default: nil
  # A log rather than a document: it opens on its newest line and follows it down.
  attr :stick_to_bottom, :boolean, default: false
  attr :rest, :global
  slot :header
  slot :inner_block, required: true

  def panel(assigns) do
    ~H"""
    <div
      id={@id}
      class={classes(["panel", @class])}
      phx-hook={if @collapsible or @stick_to_bottom, do: "Panel"}
      data-stick={if @stick_to_bottom, do: "true"}
    >
      <div class="panel-header flex">
        <h1 :if={@heading} class="header-name" phx-no-format><.panel_title title={@title} collapsible={@collapsible} collapsed={@collapsed} /></h1>
        <span :if={!@heading} class="header-name" phx-no-format><.panel_title title={@title} collapsible={@collapsible} collapsed={@collapsed} /></span>
        {render_slot(@header)}
      </div>

      <div
        id={@body_id}
        class={classes(["panel-body", @body_class, @max_height && "scrolls"])}
        hidden={@collapsible and @collapsed}
        {cap(@max_height)}
        {@rest}
      >
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  # `class` and `style` are the two attributes HEEx renders whatever their value, so a nil in either
  # leaves a stray `class="panel "` or `style=""` on every panel in the game. Both are built first,
  # and an absent cap contributes no attribute rather than an empty one.
  defp classes(parts), do: parts |> Enum.reject(&(&1 in [nil, false, ""])) |> Enum.join(" ")

  defp cap(nil), do: []
  defp cap(pixels), do: [style: "max-height: #{pixels}px"]

  attr :title, :string, required: true
  attr :collapsible, :boolean, required: true
  attr :collapsed, :boolean, required: true

  # `aria-expanded` IS the state: the arrow turns off it, so what the mark says and what a screen
  # reader is told cannot come apart.
  defp panel_title(%{collapsible: false} = assigns), do: ~H"{@title}"

  defp panel_title(assigns) do
    ~H"""
    <button type="button" class="panel-toggle" aria-expanded={to_string(!@collapsed)} phx-no-format><span class="panel-arrow" aria-hidden="true">▾</span>{@title}</button>
    """
  end

  @doc "Whose hall this is. Every place that names one says it the same way."
  def hall_of(nil), do: "All"
  def hall_of(race), do: race.label

  # ------------------------------------------------------------------ alerts

  @doc """
  A rejected action, surfaced inline on the current screen rather than as a full-screen error.
  Dismissed by its own corner glyph — never by clicking the banner, which would make it far too
  easy to lose the message by accident.
  """
  attr :message, :string, required: true

  def notice(assigns) do
    ~H"""
    <div class="alert alert-danger alert-dismissible">
      {@message}
      <button type="button" class="alert-dismiss" aria-label="Dismiss" phx-click="dismiss_notice">
        ×
      </button>
    </div>
    """
  end

  @doc """
  The result of an action. One-shot and NOT dismissible: it belongs to the action that produced it
  and disappears the moment you leave the screen, so there is nothing to dismiss.
  """
  attr :flash, :map, required: true

  def flash_alert(assigns) do
    ~H|<div class={"alert alert-#{@flash.type}"}>{raw(@flash.text)}</div>|
  end

  attr :ambushed, :boolean, default: false
  attr :ambush_line, :string, default: nil

  def low_health(assigns) do
    ~H"""
    <div id="low-health-alert" class="alert alert-danger">
      Your HP is dangerously low!<br />
      <%= if @ambushed do %>
        {@ambush_line}
      <% else %>
        You should buy some food from the 🍺 <.link patch={Paths.for_screen("inn")}>Inn</.link>
        to regain your strength.
      <% end %>
    </div>
    """
  end

  # --------------------------------------------------------------- the way back

  attr :started, :boolean, required: true
  attr :dead, :boolean, default: false
  attr :label, :string, default: nil
  attr :class, :string, default: "last back"
  # Named outright where "where you came from" is neither Town nor Game Start.
  attr :to, :string, default: nil

  def back_link(assigns) do
    # Named up here so the anchor can sit flush against its text: a newline inside a link renders
    # as a space, and the underline covers it.
    assigns =
      assign(assigns,
        href: Paths.for_screen(assigns.to || whence(assigns.started, assigns.dead)),
        text: assigns.label || whence_label(assigns.started, assigns.dead)
      )

    ~H"""
    <p class={@class}>
      <.link patch={@href}>{@text}</.link>
    </p>
    """
  end

  # The dead go back to their own ending. Patching to Town would be bounced there anyway, so this
  # is about the promise the link makes, not where it lands.
  defp whence(_started, true), do: "death"
  defp whence(true, _dead), do: "home"
  defp whence(false, _dead), do: "start"

  defp whence_label(_started, true), do: "Return to your final rest"
  defp whence_label(true, _dead), do: "Continue your journey"
  defp whence_label(false, _dead), do: "Go back to game start"

  attr :race, :map, default: nil

  def halls_link(assigns) do
    assigns =
      assign(assigns,
        href: Paths.for_screen("highscores", assigns.race && assigns.race.slug),
        text: "Go back to the Hall of #{hall_of(assigns.race)} Champions"
      )

    ~H"""
    <p class="last back">
      <.link patch={@href}>{@text}</.link>
    </p>
    """
  end

  # ------------------------------------------------------------- action form

  @doc """
  One `<select>` driving a companion button's label and variant — the shared form behind Town, the
  shops and Suicide. Submitting with the placeholder selected is a legitimate "go home", so the
  button is never disabled; until the PLAYER picks, it reads `default_label`.
  """
  attr :event, :string, required: true
  attr :name, :string, required: true
  attr :options, :list, required: true
  attr :placeholder, :string, default: nil
  attr :picked, :string, default: nil
  attr :default_label, :string, required: true
  attr :active_label, :any, required: true
  attr :default_variant, :string, default: "btn-secondary"
  attr :active_variant, :any, default: "btn"
  slot :hidden

  def select_action_form(assigns) do
    picked = assigns.picked
    chosen? = picked not in [nil, ""]

    assigns =
      assign(assigns,
        label:
          if(chosen?, do: resolve(assigns.active_label, picked), else: assigns.default_label),
        variant:
          button_class(
            if(chosen?,
              do: resolve(assigns.active_variant, picked),
              else: assigns.default_variant
            )
          )
      )

    ~H"""
    <form phx-submit={@event} phx-change="pick">
      {render_slot(@hidden)}
      <div class="form-row">
        <%!-- `selected` is rendered explicitly: re-rendering the option list to relabel the button
              would otherwise drop the player's choice on the floor. --%>
        <select name={@name} class="form-select">
          <option :if={@placeholder} value="" selected={@picked in [nil, ""]}>{@placeholder}</option>
          <option
            :for={option <- @options}
            value={option.value}
            disabled={option[:disabled?]}
            selected={@picked == option.value}
          >
            {option.label}
          </option>
        </select>
        <button type="submit" class={@variant}>{@label}</button>
      </div>
    </form>
    """
  end

  defp resolve(fun, value) when is_function(fun, 1), do: fun.(value)
  defp resolve(value, _picked), do: value

  defp button_class("btn"), do: "btn"
  defp button_class(variant), do: "btn #{variant}"

  attr :key, :string, required: true
  attr :count, :integer, required: true
  attr :singular, :string, required: true
  attr :plural, :string, required: true
  attr :emoji, :string, default: nil
  attr :class, :string, default: "tally"

  @doc false
  # A figure and the noun it counts. Only the figure counts — a tally of the slain climbs by a
  # group at a time, so it has distance to cover, while the noun beside it does not. At one there
  # is no figure to tween at all: "a cunning ambush" is a word.
  def counted(%{count: 1} = assigns) do
    ~H|<span class={@class}>{Format.pluralize(@singular, @plural, 1, @emoji)}</span>|
  end

  def counted(assigns) do
    assigns =
      assign(assigns,
        noun: Enum.join(Enum.reject([assigns.emoji, assigns.plural], &is_nil/1), " ")
      )

    ~H"""
    <span class={@class} phx-no-format><span data-key={@key} data-value={@count}>{Format.number(@count)}</span> {@noun}</span>
    """
  end

  # ------------------------------------------------------------------ stamps

  attr :id, :string, required: true
  attr :at, :any, required: true
  attr :class, :string, default: "minor"

  @doc false
  # The text is UTC and correct without JS; the hook rewrites it to wherever the reader is.
  def stamp(assigns) do
    ~H"""
    <time id={@id} class={@class} phx-hook="LocalTime" datetime={DateTime.to_iso8601(@at)}>{short_date(
      @at
    )}</time>
    """
  end

  defp short_date(at) do
    pad = &String.pad_leading(Integer.to_string(&1), 2, "0")

    "#{pad.(at.day)}/#{pad.(at.month)}/#{String.slice(Integer.to_string(at.year), -2..-1)}, " <>
      "#{pad.(at.hour)}:#{pad.(at.minute)}"
  end
end
