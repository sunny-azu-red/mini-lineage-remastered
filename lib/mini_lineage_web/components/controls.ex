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

  # Folds on a click of its header, wherever the stylesheet's `--folds` is not 0: a layout may keep
  # a panel open where there is room for it, and the hook reads the answer rather than a breakpoint.
  attr :collapsible, :boolean, default: false
  # Where a collapsible panel starts. The reader's own toggling outlives a patch but not a mount.
  attr :collapsed, :boolean, default: false
  # Whether the reader's last fold is kept for the next mount. False starts every visit afresh.
  attr :remember, :boolean, default: true
  # Whose content the panel holds. When it changes the hook starts over, as a fresh mount would,
  # since patching from one record to the next keeps the same element.
  attr :subject, :string, default: nil
  # Pixels. Given one, the BODY scrolls — so the bar sits against the panel's edge rather than
  # inside the body's padding, and the page is the same height however much is in it.
  attr :max_height, :integer, default: nil

  # A body that scrolls in whatever height the stylesheet gives it, where a layout decides the cap.
  attr :scrolls, :boolean, default: false

  # A log rather than a document, in the order it reads: a chronicle newest first, a chat oldest
  # first. Its present edge is the newest line's; a reader away from it keeps their place when an
  # entry arrives, and is shown what arrived while they were away.
  attr :log, :atom, values: [nil, :newest_first, :oldest_first], default: nil
  # The event a log asks for its previous page with, when its list carries `data-older-than`.
  attr :load_older, :string, default: nil
  # The event the reader says with whether they are at the present, sent only as that changes, so
  # the server can let the oldest go as the newest lands.
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
      <button
        :if={@unread}
        type="button"
        class="btn btn-sm panel-unread"
        data-one={elem(@unread, 0)}
        data-many={elem(@unread, 1)}
        data-rest={if @log == :oldest_first, do: "more below", else: "more above"}
        hidden
      >👁️ <span></span></button>
    </div>
    """
  end

  # `class` and `style` are the two attributes HEEx renders whatever their value, so a nil in either
  # leaves a stray `class="panel "` or `style=""` on every panel in the game. Both are built first,
  # and an absent cap contributes no attribute rather than an empty one.
  defp classes(parts), do: parts |> Enum.reject(&(&1 in [nil, false, ""])) |> Enum.join(" ")

  defp cap(nil), do: []
  defp cap(pixels), do: [style: "max-height: #{pixels}px"]

  # A BUTTON rather than a link: this goes nowhere, and Space activates a button where it scrolls a
  # link. `aria-expanded` IS the state the arrow turns off, so the mark and the screen reader
  # cannot come apart.
  defp folds(false, _collapsed), do: []
  defp folds(true, collapsed), do: [type: "button", "aria-expanded": to_string(!collapsed)]

  @doc "Whose hall this is. Every place that names one says it the same way."
  def hall_of(nil), do: "All"
  def hall_of(race), do: race.label

  # ------------------------------------------------------------------ tables

  @doc """
  Every table in the game: the container, the header row, and a sort wherever a column names one.
  The rows are the caller's, as a `<tbody>` in the inner block, already in `sort`'s order.

  A `:col` with `sort` is a button that sends `sort` with this table's id and that key; the
  LiveView cycles it through `next_sort/3` and the screen orders its rows with `sort_rows/3`, so a
  live patch never fights the order. `remember` keeps the reader's sort under `table:<id>`, which
  `app.js` hands back as the socket connects.
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
  Offers to reset a table's sort, and only while it has one. The screen places it, since where
  it belongs is beside that screen's own controls rather than over the table.
  """
  attr :table, :string, required: true
  attr :sort, :any, default: nil

  def reset_sort(assigns) do
    ~H"""
    <button
      :if={@sort}
      id={"#{@table}-reset"}
      type="button"
      class="btn btn-secondary btn-sm reset-sort"
      phx-click="reset_sort"
      phx-value-table={@table}
    >
      Reset Sort
    </button>
    """
  end

  @doc "A click on `key`: the way it `first` goes, then the other way, then back to no sort at all."
  def next_sort({key, first}, key, first), do: {key, flip(first)}
  def next_sort({key, _other}, key, _first), do: nil
  def next_sort(_sort, key, first), do: {key, first}

  defp flip(:asc), do: :desc
  defp flip(:desc), do: :asc

  @doc """
  Rows in `sort`'s order by `key_of.(row, key)`. Stable, so rows equal on the column keep the order
  they came in, which is what stops equal rows trading places on every live patch.
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

  # The anchor sits flush against its text: a newline inside a link renders as a space the underline
  # then covers. The mark sits OUTSIDE it, so a click lands on the words, and is muted because it
  # says which way this goes and nothing else.
  defp back(assigns) do
    ~H"""
    <p class={@class}>
      <span class="muted">&laquo;</span> <.link patch={@href}>{@text}</.link>
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
  attr :class, :string, required: true

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

  attr :id, :string, default: nil
  attr :at, :any, required: true

  @doc false
  # The text is UTC and correct without JS. It carries no hook of its own: whatever holds it carries
  # one `LocalTimes`, which rewrites every stamp beneath it to wherever the reader is.
  def stamp(assigns) do
    ~H"""
    <time id={@id} class="date" datetime={DateTime.to_iso8601(@at)}>{short_date(@at)}</time>
    """
  end

  defp short_date(at) do
    pad = &String.pad_leading(Integer.to_string(&1), 2, "0")

    "#{pad.(at.day)}/#{pad.(at.month)}/#{String.slice(Integer.to_string(at.year), -2..-1)}, " <>
      "#{pad.(at.hour)}:#{pad.(at.minute)}"
  end
end
