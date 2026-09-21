defmodule MiniLineageWeb.Screens.Halls do
  @moduledoc """
  The Hall of Champions, filtered to one lineage or to all of them. A view of the characters rather
  than a table of its own, so a run appears the moment it chooses a race and keeps its place when
  it ends.
  """
  use MiniLineageWeb, :html

  import MiniLineageWeb.Controls

  alias MiniLineage.Game.Format
  alias MiniLineageWeb.Paths

  attr :view, :map, required: true
  attr :catalog, :map, required: true
  attr :boards, :map, default: %{}
  attr :character_id, :string, default: nil
  attr :race_filter, :integer, default: nil

  def screen(assigns) do
    filter = Enum.find(assigns.catalog.races, &(&1.id == assigns.race_filter))

    assigns =
      assign(assigns,
        rows: Map.get(assigns.boards, assigns.race_filter, []),
        filter_slug: filter && filter.slug
      )

    ~H"""
    <%!-- `top` is load-bearing: it pulls the row up to the panel edge and puts the 12px gap
          below it instead, where the table needs it. --%>
    <div class="action-links top">
      <.link
        patch={Paths.for_screen("highscores")}
        class={"btn btn-secondary btn-sm#{if is_nil(@race_filter), do: " active"}"}
      >
        All
      </.link>
      <.link
        :for={race <- @catalog.races}
        patch={Paths.for_screen("highscores", race.slug)}
        class={"btn btn-secondary btn-sm#{if @race_filter == race.id, do: " active"}"}
      >
        {race.emoji} {race.label}
      </.link>
    </div>

    <%= if @rows == [] do %>
      <p>
        The Hall is silent. No soul has yet earned a place among these hallowed pillars. The
        chronicle of champions awaits its first entry. Will your name be the first to echo through
        eternity?
      </p>
    <% else %>
      <div class="table-container">
        <table class="data-table" style="min-width:520px">
          <thead>
            <tr>
              <th class="name">Name</th>
              <th class="num">Level</th>
              <th class="num">Total XP</th>
              <th>Wealth</th>
              <th>Date</th>
            </tr>
          </thead>
          <%!-- The hook animates every [data-value] beneath it and sweeps every [data-stamp] whose
                stamp has moved, so one hook covers the whole board. --%>
          <tbody id="halls-rows" phx-hook="AnimatedValues">
            <.character_row
              :for={row <- @rows}
              catalog={@catalog}
              row={row}
              mine={row.id == @character_id}
              from={@filter_slug}
            />
          </tbody>
        </table>
      </div>
    <% end %>

    <.back_link started={@view.started} dead={@view.dead} class="last" />
    """
  end

  attr :catalog, :map, required: true
  attr :row, :map, required: true
  attr :mine, :boolean, default: false
  attr :from, :string, default: nil

  defp character_row(assigns) do
    assigns = assign(assigns, name: String.slice(assigns.row.name || "", 0, 20))

    ~H"""
    <%!-- Keyed by the character and never by the row: the board reorders under a climb, so a key
          tied to a position would count a stranger's total into this one's.
          The stamp is what the row SHOWS, not when it was written. On `updated_at` the sweep fired
          for writes with nothing to see — starting over clears the old run's session, which moves
          the date and drops the green, and swept a row whose figures had not changed. --%>
    <tr
      class={["character-row", still_going?(@row) && "alive", @mine && "mine"]}
      data-key={"row-#{@row.id}"}
      data-stamp={"#{@row.level}/#{@row.total_xp}/#{@row.adena}/#{@row.dead}"}
    >
      <td class="name">
        {race_emoji(@catalog, @row.race_id)}
        <.link patch={Paths.for_character(@row.id, @from)}>{@name}</.link>
        <span :if={@row.medal} title={medal_title(@row.medal)}>{medal(@row.medal)}</span>
        <%!-- Always rendered, never `:if`: a span that comes and goes cannot fade, and holding the
              width means no name shifts sideways when somebody arrives. Last in the cell for the
              same reason — the width it holds while dark falls where nothing follows it, rather
              than opening a gap between the name and the medal. --%>
        <span
          class={["online", @row.online && "lit"]}
          title={@row.online && "Online right now"}
          aria-hidden={if @row.online, do: "false", else: "true"}
        >&bull;</span>
      </td>
      <td class="num level">
        <span data-key={"level-#{@row.id}"} data-value={@row.level}>{Format.number(@row.level)}</span>
      </td>
      <td class="num xp">
        <span data-key={"xp-#{@row.id}"} data-value={@row.total_xp}>{Format.number(@row.total_xp)}</span>
      </td>
      <td class="adena">
        🪙
        <span data-key={"adena-#{@row.id}"} data-format="adena" data-value={@row.adena}>{Format.adena(
          @row.adena
        )}</span>
      </td>
      <td><.stamp id={"seen-#{@row.id}"} at={@row.last_action_at} /></td>
    </tr>
    """
  end

  # A run is going while it has neither died nor lost its session. Without one it is missing: it
  # can never be played again, so it is over even though it never died.
  defp still_going?(row), do: not row.dead and row.active

  defp medal(1), do: "🥇"
  defp medal(2), do: "🥈"
  defp medal(3), do: "🥉"

  defp medal_title(1), do: "First in the Hall"
  defp medal_title(2), do: "Second in the Hall"
  defp medal_title(3), do: "Third in the Hall"

  defp race_emoji(catalog, race_id) do
    case Enum.find(catalog.races, &(&1.id == race_id)) do
      nil -> "❓"
      race -> race.emoji
    end
  end
end
