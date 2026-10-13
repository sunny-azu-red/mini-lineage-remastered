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
  Every `.btn` in the game. With `patch` it is a link, because it goes somewhere and a reader may
  want it in a new tab; without, a `<button>`, because it does something. The variant decides how it
  looks, never the element.
  """
  attr :type, :string, default: "button"
  attr :variant, :atom, default: :primary, values: [:primary, :secondary, :danger]
  attr :size, :atom, default: :normal, values: [:normal, :sm]
  # The one of a set that is already chosen, pressed in: the Halls' current filter.
  attr :active, :boolean, default: false
  attr :patch, :string, default: nil
  attr :class, :string, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def button(assigns) do
    assigns =
      assign(assigns,
        classes:
          classes([
            "btn",
            assigns.variant == :secondary && "btn-secondary",
            assigns.variant == :danger && "btn-danger",
            assigns.size == :sm && "btn-sm",
            assigns.active && "active",
            assigns.class
          ])
      )

    ~H"""
    <.link :if={@patch} patch={@patch} class={@classes} {@rest}>{render_slot(@inner_block)}</.link>
    <button :if={!@patch} type={@type} class={@classes} {@rest}>{render_slot(@inner_block)}</button>
    """
  end

  @doc """
  A choice and the button that acts on it, which is how a player moves: the town's destinations, a
  Gatekeeper's routes. Until the PLAYER picks, the button reads `default_label` in the quieter look;
  a `placeholder` is the empty choice, which the event reads as going back. Every action clears the
  pick, so the choice goes back to its start; nothing else touches it, an open list included
  (`SelectAction`). Options come only from what the player's actions change, never from HP, MP or
  the hour, or a tick rewrites an open list; AGENTS.md lists what else shuts one.
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
  # What the button turns into once something is picked: `:danger` for what cannot be undone.
  attr :active_variant, :atom, default: :primary
  attr :rest, :global

  # A field named after a form property shadows it: `form.id` would return the select, and the
  # patch, keying on it, moves the form on every render, which shuts an open list.
  @shadowing ~w(id name action method target elements length submit reset)

  def select_action(%{name: name}) when name in @shadowing,
    do: raise(ArgumentError, "a select_action field may not be named #{inspect(name)}")

  def select_action(assigns) do
    # A pick the options no longer hold (a lesson just learned) falls back to the placeholder in the
    # browser, so the button must too, or it reads as acting while it goes back.
    chosen? = Enum.any?(assigns.options, &(&1.value == assigns.picked))

    # Exactly one option says it is shown, the one the browser shows: a list where none does reads to
    # LiveView as changed on every patch, and it blurs the select, shutting an open list.
    shown =
      cond do
        chosen? -> assigns.picked
        assigns.placeholder -> ""
        true -> assigns.options |> List.first(%{}) |> Map.get(:value)
      end

    assigns =
      assign(assigns,
        shown: shown,
        label: if(chosen?, do: assigns.active_label, else: assigns.default_label),
        variant: if(chosen?, do: assigns.active_variant, else: assigns.default_variant)
      )

    ~H"""
    <form id={@id} phx-submit={@event} phx-change="pick">
      <div class="form-row">
        <%!-- `selected` explicitly: relabelling the button re-renders the options, and would
              otherwise drop the player's choice. --%>
        <select id={"#{@id}-choice"} name={@name} class="form-select" phx-hook="SelectAction">
          <option :if={@placeholder} value="" selected={@shown == ""}>{@placeholder}</option>
          <option
            :for={option <- @options}
            value={option.value}
            disabled={option[:disabled?]}
            selected={@shown == option.value}
          >
            {option.label}
          </option>
        </select>
        <.button type="submit" variant={@variant} {@rest}>{@label}</.button>
      </div>
    </form>
    """
  end

  # ------------------------------------------------------------------ tables

  @doc """
  Every table in the game. The rows are the caller's `<tbody>`, already in `sort`'s order: a `:col`
  with `sort` is a header button sending `sort` with the table's id and its key, which the LiveView
  cycles with `next_sort/2` and the screen applies with `sort_rows/3`, so a patch never fights it.
  `remember` keeps the sort under `table:<id>` through the `Table` hook, handed back on connect.
  """
  attr :id, :string, required: true
  # `{key, :asc | :desc}`, or nil for the order the rows arrived in.
  attr :sort, :any, default: nil
  # Only for a table `Screens.sortable/1` also marks remembered, which reads the kept sort back.
  attr :remember, :boolean, default: false
  # Lands on the `<table>`.
  attr :rest, :global

  slot :col, required: true do
    attr :class, :string
    attr :title, :string
    # Without one the header is only a label.
    attr :sort, :string
  end

  slot :inner_block, required: true

  def data_table(assigns) do
    ~H"""
    <div class="table-container">
      <table id={@id} class="data-table" {@rest}>
        <thead
          id={@remember && "#{@id}-head"}
          phx-hook={@remember && "Table"}
          data-table={@remember && @id}
          data-sort={@remember && encode_sort(@sort)}
        >
          <tr>
            <%= for col <- @col do %>
              <th :if={!col[:sort]} title={col[:title]} {column(col, nil)}>{render_slot(col)}</th>
              <th :if={col[:sort]} title={col[:title]} {column(col, @sort)}>
                <button
                  type="button"
                  class="sort"
                  phx-click="sort"
                  phx-value-table={@id}
                  phx-value-key={col.sort}
                ><span>{render_slot(col)}</span><span class="sort-arrow" aria-hidden="true"></span></button>
              </th>
            <% end %>
          </tr>
        </thead>
        {render_slot(@inner_block)}
      </table>
    </div>
    """
  end

  # Spread, so a column with no class prints no `class=""`.
  defp column(col, sort) do
    Enum.reject(
      [class: col[:class], "aria-sort": aria_sort(sort, col[:sort])],
      &is_nil(elem(&1, 1))
    )
  end

  defp aria_sort({key, :asc}, key), do: "ascending"
  defp aria_sort({key, :desc}, key), do: "descending"
  defp aria_sort(_sort, _key), do: nil

  @doc "A click on `key`: ascending, then descending, then back to the order the rows arrived in."
  def next_sort({key, :asc}, key), do: {key, :desc}
  def next_sort({key, :desc}, key), do: nil
  def next_sort(_sort, key), do: {key, :asc}

  @doc """
  Rows in `sort`'s order by `key_of.(row, key)`. Stable, so rows equal on the column keep the
  order they arrived in rather than trading places on a patch.
  """
  def sort_rows(rows, nil, _key_of), do: rows
  def sort_rows(rows, {key, dir}, key_of), do: Enum.sort_by(rows, &key_of.(&1, key), dir)

  # The empty string, not nil, so the hook sees a sort undone as a change.
  defp encode_sort(nil), do: ""
  defp encode_sort({key, dir}), do: "#{key}:#{dir}"

  @doc """
  A kept sort read back against the keys a table offers today. Storage is the reader's to edit, so
  anything that is not one of them is no sort at all.
  """
  def decode_sort(value, keys) when is_binary(value) and is_list(keys) do
    with [key, dir] <- String.split(value, ":"),
         true <- key in keys,
         {:ok, dir} <- Map.fetch(%{"asc" => :asc, "desc" => :desc}, dir) do
      {key, dir}
    else
      _ -> nil
    end
  end

  def decode_sort(_value, _keys), do: nil

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
    <.alert id="flash" kind={@flash.type}>
      <%!-- A hunt's fight log (rules §20) comes before what it came to. --%>
      <ol :if={@flash[:log]} id="fight-log" class="fight-log">
        <li :for={line <- @flash.log}>{raw(line)}</li>
      </ol>
      {raw(@flash.text)}
    </.alert>
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
  attr :format, :atom, default: :number, values: [:number, :short, :percent, :tenths]
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
  defp figure_text(:tenths, value), do: Format.tenths(value)

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
  # one figure instead, the share of `of` in whole percent, keyed `<key>-percent`.
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
        value={Math.floor_percent(@value, @of)}
        format={:percent}
      /></span>
      <span :if={!@percent?} class="bar-text" phx-no-format><.figure key={@key} value={@value} format={@format} /><span :if={@of}>&nbsp;/&nbsp;<.figure key={@of_key} value={@of} format={@format} /></span></span>
    </div>
    """
  end
end
