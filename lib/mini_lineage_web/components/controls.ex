defmodule MiniLineageWeb.Controls do
  @moduledoc """
  What every screen reaches for and no screen owns: the panel, the button, the table, the alerts,
  the action form, the way back, and the stamp. `raw/1` renders narratives and flashes, which the
  server composes from the template tables — never from anything a player typed.
  """
  use MiniLineageWeb, :html

  alias MiniLineage.Game.{Clock, Format}
  alias MiniLineageWeb.Paths

  # ------------------------------------------------------------------- panels

  @doc """
  The card every part of the game is drawn on: a header band and a body under it.

  `id` names the PANEL, for its hook; `body_id` and every other attribute land on the BODY, which
  is what a screen is addressed by. A panel carries a hook only when something about it moves, so
  the error page, with no LiveView, renders one that asks for no JavaScript.
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
  # Whose content the panel holds; when it changes the hook starts over, since patching from one
  # record to the next keeps the same element.
  attr :subject, :string, default: nil
  # Pixels. The BODY scrolls, so the bar sits against the panel's edge, not inside its padding.
  attr :max_height, :integer, default: nil

  # A body that scrolls in whatever height the stylesheet gives it, where a layout decides the cap.
  attr :scrolls, :boolean, default: false

  # A log rather than a document, in the order it reads: a chronicle newest first, a chat oldest
  # first. The `Log` hook keeps a reader's place away from the present and counts what they missed.
  attr :log, :atom, values: [nil, :newest_first, :oldest_first], default: nil
  # The event a log asks for its previous page with, when its list carries `data-older-than`.
  attr :load_older, :string, default: nil

  # Sent only as whether the reader is at the present changes, so the server can let the oldest go.
  attr :at_present, :string, default: nil

  # What the pill over the present edge counts, singular and plural: `{"new entry", "new entries"}`.
  attr :unread, :any, default: nil
  attr :rest, :global
  slot :header
  slot :inner_block, required: true

  def panel(assigns) do
    ~H"""
    <div
      id={@id}
      class={classes(["panel", @class])}
      phx-hook={if @collapsible or @log, do: "Panel"}
      data-log={@log && String.replace(to_string(@log), "_", "-")}
      data-load-older={@load_older}
      data-at-present={@at_present}
      data-remember={if !@remember, do: "false"}
      data-subject={@subject}
    >
      <%!-- The whole band is the control, not the words in it: a header is a wide, obvious thing
            to aim at, and a title you have to hit exactly is a worse target than no control. --%>
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

      <div
        id={@body_id}
        class={classes(["panel-body", @body_class, (@max_height || @scrolls) && "scrolls"])}
        {cap(@max_height)}
        {@rest}
      >
        {render_slot(@inner_block)}
      </div>

      <%!-- Shown and worded only by the hook, and only for entries that arrived while the reader
            was away; `rest` is what it says once they have reached the first of them. --%>
      <.button
        :if={@unread}
        size={:sm}
        class="panel-unread"
        data-one={elem(@unread, 0)}
        data-many={elem(@unread, 1)}
        data-rest={if @log == :oldest_first, do: "more below", else: "more above"}
        hidden
      >👁️ <span></span></.button>
    </div>
    """
  end

  # HEEx renders `class` and `style` whatever their value, so both are built first and an absent
  # cap contributes no attribute at all.
  defp classes(parts), do: parts |> Enum.reject(&(&1 in [nil, false, ""])) |> Enum.join(" ")

  defp cap(nil), do: []
  defp cap(pixels), do: [style: "max-height: #{pixels}px"]

  # A BUTTON rather than a link: this goes nowhere, and Space activates a button but scrolls a link.
  # `aria-expanded` IS the state the arrow turns off, so the mark and the screen reader agree.
  defp folds(false, _collapsed), do: []
  defp folds(true, collapsed), do: [type: "button", "aria-expanded": to_string(!collapsed)]

  @doc "Whose hall this is. Every place that names one says it the same way."
  def hall_of(nil), do: "All"
  def hall_of(race), do: race.label

  # ----------------------------------------------------------------- buttons

  @doc """
  Every `.btn` in the game. With `patch` it is a link, because it goes somewhere and a reader may
  want it in a new tab; without, a `<button>`, because it does something. The variant decides how
  it looks, never the element.
  """
  attr :variant, :atom, default: :primary, values: [:primary, :secondary, :danger]
  attr :size, :atom, default: :normal, values: [:normal, :sm]
  # The one of a set that is already chosen, pressed in: the Halls' current filter.
  attr :active, :boolean, default: false
  attr :patch, :string, default: nil
  attr :type, :string, default: "button"
  attr :class, :string, default: nil
  attr :rest, :global, include: ~w(disabled form name value)
  slot :inner_block, required: true

  def button(assigns) do
    assigns =
      assign(assigns,
        classes:
          classes([
            "btn",
            variant_class(assigns.variant),
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

  defp variant_class(:primary), do: nil
  defp variant_class(variant), do: "btn-#{variant}"

  # ------------------------------------------------------------------ tables

  @doc """
  Every table in the game: the container, the header row, and a sort wherever a column names one.
  The rows are the caller's, as a `<tbody>` in the inner block, already in `sort`'s order.

  A `:col` with `sort` is a button sending `sort`; the LiveView cycles it with `next_sort/3` and
  the screen orders its rows with `sort_rows/3`, so a patch never fights the order. `remember`
  keeps it under `table:<id>`.
  """
  attr :id, :string, required: true
  # `{key, :asc | :desc}`, or nil for the order the rows arrived in.
  attr :sort, :any, default: nil
  attr :remember, :boolean, default: true
  # Lands on the `<table>`, which is where a screen's own hook goes.
  attr :rest, :global

  slot :col, required: true do
    attr :class, :string
    attr :title, :string
    # The key this column sorts by. Without one the header is a label and nothing else.
    attr :sort, :string
  end

  slot :inner_block, required: true

  def data_table(assigns) do
    assigns = assign(assigns, sortable: Enum.any?(assigns.col, & &1[:sort]))

    ~H"""
    <div class="table-container">
      <table id={@id} class="data-table" {@rest}>
        <thead
          id={@sortable && "#{@id}-head"}
          phx-hook={@sortable && "Table"}
          data-table={@sortable && @id}
          data-sort={encode_sort(@sort)}
          data-remember={if @sortable and !@remember, do: "false"}
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

  @doc """
  Offers to reset a table's sort, only while it has one. The screen places it beside its own
  controls.
  """
  attr :table, :string, required: true
  attr :sort, :any, default: nil

  def reset_sort(assigns) do
    ~H"""
    <.button
      :if={@sort}
      id={"#{@table}-reset"}
      variant={:secondary}
      size={:sm}
      class="reset-sort"
      phx-click="reset_sort"
      phx-value-table={@table}
    >
      Reset Sort
    </.button>
    """
  end

  @doc "A click on `key`: the way it `first` goes, then the other way, then back to no sort at all."
  def next_sort({key, first}, key, first), do: {key, flip(first)}
  def next_sort({key, _other}, key, _first), do: nil
  def next_sort(_sort, key, first), do: {key, first}

  defp flip(:asc), do: :desc
  defp flip(:desc), do: :asc

  @doc """
  Rows in `sort`'s order by `key_of.(row, key)`. Stable, so rows equal on the column do not trade
  places on every live patch.
  """
  def sort_rows(rows, nil, _key_of), do: rows
  def sort_rows(rows, {key, dir}, key_of), do: Enum.sort_by(rows, &key_of.(&1, key), dir)

  def encode_sort(nil), do: nil
  def encode_sort({key, dir}), do: "#{key}:#{dir}"

  @doc """
  A kept sort read back against the columns a table offers today, `%{key => first direction}`.
  Storage is the reader's to edit, so anything that is not one of them is no sort at all.
  """
  def decode_sort(value, columns) when is_binary(value) and is_map(columns) do
    with [key, dir] <- String.split(value, ":"),
         true <- Map.has_key?(columns, key),
         {:ok, dir} <- Map.fetch(%{"asc" => :asc, "desc" => :desc}, dir) do
      {key, dir}
    else
      _ -> nil
    end
  end

  def decode_sort(_value, _columns), do: nil

  # ------------------------------------------------------------------ alerts

  @doc """
  A rejected action, inline on the current screen. Dismissed by its corner glyph, never by a
  click on the banner, which would lose the message too easily.
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
  The result of an action. Not dismissible: it disappears the moment you leave the screen.
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

  def back_link(assigns) do
    ~H"""
    <.back
      href={Paths.for_screen(whence(@started, @dead))}
      text={@label || whence_label(@started, @dead)}
      class={@class}
    />
    """
  end

  attr :href, :string, required: true
  attr :text, :string, required: true
  attr :class, :string, default: "last back"

  # The anchor sits flush against its text. The mark sits OUTSIDE it, so a click lands on the
  # words, and is muted because it says which way this goes and nothing else.
  defp back(assigns) do
    ~H"""
    <p class={@class}>
      <span class="muted">&laquo;</span> <.link patch={@href}>{@text}</.link>
    </p>
    """
  end

  # The dead go back to their ending: Town would bounce them there anyway, but the link says so.
  defp whence(_started, true), do: "death"
  defp whence(true, _dead), do: "home"
  defp whence(false, _dead), do: "start"

  defp whence_label(_started, true), do: "Return to your final rest"
  defp whence_label(true, _dead), do: "Continue your journey"
  defp whence_label(false, _dead), do: "Go back to game start"

  attr :race, :map, default: nil

  def halls_link(assigns) do
    ~H"""
    <.back
      href={Paths.for_screen("highscores", @race && @race.slug)}
      text={"Go back to the Hall of #{hall_of(@race)} Champions"}
    />
    """
  end

  # ------------------------------------------------------------- action form

  @doc """
  One `<select>` driving a companion button's label and variant — the shared form behind Town, the
  shops and Suicide. Submitting with the placeholder selected is a legitimate "go home", so the
  button is never disabled; until the PLAYER picks, it reads `default_label`.
  """
  # LiveView restores a form's pick after a reconnect only when the form has an id.
  attr :id, :string, required: true
  attr :event, :string, required: true
  attr :name, :string, required: true
  attr :options, :list, required: true
  attr :placeholder, :string, default: nil
  attr :picked, :string, default: nil
  attr :default_label, :string, required: true
  attr :active_label, :any, required: true
  attr :default_variant, :atom, default: :secondary
  attr :active_variant, :any, default: :primary
  slot :hidden

  def select_action_form(assigns) do
    picked = assigns.picked
    chosen? = picked not in [nil, ""]

    assigns =
      assign(assigns,
        label:
          if(chosen?, do: resolve(assigns.active_label, picked), else: assigns.default_label),
        variant:
          if(chosen?, do: resolve(assigns.active_variant, picked), else: assigns.default_variant)
      )

    ~H"""
    <form id={@id} phx-submit={@event} phx-change="pick">
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
        <.button type="submit" variant={@variant}>{@label}</.button>
      </div>
    </form>
    """
  end

  defp resolve(fun, value) when is_function(fun, 1), do: fun.(value)
  defp resolve(value, _picked), do: value

  attr :key, :string, required: true
  attr :count, :integer, required: true
  attr :singular, :string, required: true
  attr :plural, :string, required: true
  attr :emoji, :string, default: nil
  attr :class, :string, required: true

  @doc false
  # A figure and the noun it counts, apart, so only the figure tweens. At one there is no figure
  # at all: "a cunning ambush" is a word.
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

  @cap_ms :timer.hours(24 * Application.compile_env(:mini_lineage, :stamp_relative_days, 7))

  attr :id, :string, default: nil
  attr :at, :any, required: true
  # `:short` for a log's heads ("4m ago"); `:long` for a sentence and a board ("4 minutes ago").
  attr :form, :atom, default: :long, values: [:short, :long]

  # A date's shape, never an age's: "on 12 Sep" in a sentence, the clock beside it, and "at 9:05 am"
  # rather than ", 9:05 am" where it is spoken. An age takes none of them, so prose writes none.
  attr :on, :boolean, default: false
  attr :time, :boolean, default: false
  attr :at_time, :boolean, default: false

  @doc """
  When something happened: its age inside the cap, its date past it, and the whole instant in the
  tooltip. The server's text is right without JS; whatever holds stamps spreads `stamps/0` and one
  `Stamps` hook ages every one beneath it and moves the dates to the reader's own zone.
  """
  def stamp(assigns) do
    at = DateTime.to_unix(assigns.at, :millisecond)

    assigns =
      assign(assigns,
        iso: DateTime.to_iso8601(assigns.at),
        label:
          Format.stamp(at, Clock.now_ms(), @cap_ms, assigns.form,
            on: assigns.on,
            time: assigns.time,
            at_time: assigns.at_time
          ),
        title: Format.stamp_title(at)
      )

    ~H"""
    <time
      id={@id}
      class="date"
      datetime={@iso}
      title={@title}
      data-form={@form}
      data-on={@on}
      data-time={@time}
      data-at-time={@at_time}
    >{@label}</time>
    """
  end

  @doc """
  What a container of stamps spreads onto itself. The hook reads the server's clock once, on mount,
  so a reader whose clock is wrong still ages each stamp from the frame the server drew.
  """
  def stamps, do: ["phx-hook": "Stamps", "data-now": Clock.now_ms(), "data-cap-ms": @cap_ms]
end
