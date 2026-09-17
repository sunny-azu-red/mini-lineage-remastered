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
        <table class="data-table" style="min-width:540px">
          <thead>
            <tr>
              <th class="name">Name</th>
              <th class="num">Level</th>
              <th class="num">Total XP</th>
              <th class="num">🪙 Wealth</th>
              <th>Date</th>
            </tr>
          </thead>
          <tbody>
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
    <tr class={["character-row", still_going?(@row) && "alive", @mine && "mine"]}>
      <td class="name">
        {race_emoji(@catalog, @row.race_id)}
        <.link patch={Paths.for_character(@row.id, @from)}>{@name}</.link>
        <span :if={@row.online} class="online" title="Online right now">•</span>
        <span :if={@row.medal} title={medal_title(@row.medal)}>{medal(@row.medal)}</span>
      </td>
      <td class="num gold">{Format.number(@row.level)}</td>
      <td class="num xp">{Format.number(@row.total_xp)}</td>
      <td class="num gold">{Format.adena(@row.adena)}</td>
      <td><.stamp id={"seen-#{@row.id}"} at={@row.updated_at} /></td>
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
