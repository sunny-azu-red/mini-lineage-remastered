defmodule MiniLineageWeb.Screens.Halls do
  @moduledoc """
  The Monument of Heroes, Interlude's obelisk to its heroes, carrying every run: filtered to one
  lineage or to all of them. A view of the characters rather
  than a table of its own, so a run appears the moment it chooses a race and keeps its place when it
  ends, whether it fell (rules §21) or went missing.
  """
  use MiniLineageWeb, :html

  import MiniLineageWeb.Controls

  alias MiniLineageWeb.{Paths, Screens}

  attr :catalog, :map, required: true
  attr :boards, :map, required: true
  # A lineage's slug, or nil for every run.
  attr :lineage, :string, default: nil
  # The reader's own run, marked on the board; nil for a visitor.
  attr :character_id, :string, default: nil
  attr :sorts, :map, default: %{}

  def screen(assigns) do
    race = Enum.find(assigns.catalog.races, &(&1.slug == assigns.lineage))
    sort = Screens.sort_of(assigns.sorts, "halls-table")
    rows = Map.get(assigns.boards, race && race.id, [])
    assigns = assign(assigns, sort: sort, rows: sort_rows(rows, sort, &row_key/2))

    ~H"""
    <%!-- `top` puts the gap below the row, above the table it filters. --%>
    <div class="action-links top">
      <.button
        variant={:secondary}
        size={:sm}
        active={is_nil(@lineage)}
        patch={Paths.for_screen("highscores")}
      >
        All
      </.button>
      <.button
        :for={race <- @catalog.races}
        variant={:secondary}
        size={:sm}
        active={@lineage == race.slug}
        patch={Paths.for_screen({"highscores", race.slug})}
      >
        {race.emoji} {race.plural}
      </.button>
    </div>

    <%= if @rows == [] do %>
      <p id="halls-empty">
        The Monument stands bare. No hero has yet earned a place upon its stone, and it waits for the
        first name to be carved. Will it be yours?
      </p>
    <% else %>
      <%!-- The board arrives ranked; a medal keeps the rank legible under any other sort. --%>
      <.data_table id="halls-table" sort={@sort}>
        <:col class="name" sort="name">Name</:col>
        <:col class="num" sort="level">Level</:col>
        <:col class="num" sort="total_xp">Total XP</:col>
        <:col sort="adena">Wealth</:col>
        <%!-- One hook for the whole board: every figure beneath it counts. --%>
        <tbody id="halls-rows" phx-hook="AnimatedValues">
          <.character_row
            :for={row <- @rows}
            catalog={@catalog}
            row={row}
            mine={row.id == @character_id}
          />
        </tbody>
      </.data_table>
    <% end %>
    """
  end

  attr :catalog, :map, required: true
  attr :row, :map, required: true
  attr :mine, :boolean, default: false

  defp character_row(assigns) do
    assigns =
      assign(assigns,
        name: String.slice(assigns.row.name || "", 0, 20),
        emoji: race_emoji(assigns.catalog, assigns.row.race_id)
      )

    ~H"""
    <%!-- Keyed by the character, never the row: the board reorders under a climb. --%>
    <tr
      id={"row-#{@row.id}"}
      class={["character-row", still_going?(@row) && "alive", @mine && "mine"]}
      data-fate={fate(@row)}
    >
      <td class="name">
        {@emoji} {@name}
        <span :if={@row.medal} title={medal_title(@row.medal)}>{medal(@row.medal)}</span>
        <span :if={@row.dead} title="Fallen">💀</span>
        <%!-- Always rendered, never `:if`: a span that comes and goes cannot fade, and its width
              keeps names from shifting. --%>
        <span
          class={["online", @row.online && "lit"]}
          title={@row.online && "Online right now"}
          aria-hidden={if @row.online, do: "false", else: "true"}
        >&bull;</span>
      </td>
      <td class="num level"><.figure key={"level-#{@row.id}"} value={@row.level} /></td>
      <td class="num xp"><.figure key={"xp-#{@row.id}"} value={@row.total_xp} /></td>
      <td class="adena">
        🪙 <.figure key={"adena-#{@row.id}"} value={@row.adena} format={:short} />
      </td>
    </tr>
    """
  end

  defp row_key(row, "name"), do: String.downcase(row.name || "")
  defp row_key(row, "level"), do: row.level
  defp row_key(row, "total_xp"), do: row.total_xp
  defp row_key(row, "adena"), do: row.adena

  # A run is going while it has neither died nor lost its session. Without one it is missing: it
  # can never be played again, so it is over even though it never died.
  defp still_going?(row), do: not row.dead and row.active

  defp fate(row) do
    cond do
      row.dead -> "fallen"
      row.active -> "living"
      true -> "missing"
    end
  end

  defp medal(1), do: "🥇"
  defp medal(2), do: "🥈"
  defp medal(3), do: "🥉"

  defp medal_title(1), do: "First on the Monument"
  defp medal_title(2), do: "Second on the Monument"
  defp medal_title(3), do: "Third on the Monument"

  defp race_emoji(catalog, race_id) do
    case Enum.find(catalog.races, &(&1.id == race_id)) do
      nil -> "❓"
      race -> race.emoji
    end
  end
end
