defmodule MiniLineageWeb.Controls do
  @moduledoc """
  What every screen reaches for and no screen owns: the alerts, the one action form behind Town and
  the shops, the way back, and a stamp on the reader's own clock.

  `raw/1` appears wherever a narrative or flash is rendered. Those strings are always composed by
  the server from the template tables — never from anything a player typed.
  """
  use MiniLineageWeb, :html

  alias MiniLineageWeb.Paths

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
    ~H"""
    <p class={@class}>
      <.link patch={Paths.for_screen(@to || whence(@started, @dead))}>
        {@label || whence_label(@started, @dead)}
      </.link>
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
    ~H"""
    <p class="last back">
      <.link patch={Paths.for_screen("highscores", @race && @race.slug)}>
        Go back to the Hall of {hall_of(@race)} Champions
      </.link>
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

  # ------------------------------------------------------------------ stamps

  attr :id, :string, required: true
  attr :at, :any, required: true

  @doc false
  # The text is UTC and correct without JS; the hook rewrites it to wherever the reader is.
  def stamp(assigns) do
    ~H"""
    <time id={@id} phx-hook="LocalTime" datetime={DateTime.to_iso8601(@at)}>{short_date(@at)}</time>
    """
  end

  defp short_date(at) do
    pad = &String.pad_leading(Integer.to_string(&1), 2, "0")

    "#{pad.(at.day)}/#{pad.(at.month)}/#{String.slice(Integer.to_string(at.year), -2..-1)}, " <>
      "#{pad.(at.hour)}:#{pad.(at.minute)}"
  end
end
