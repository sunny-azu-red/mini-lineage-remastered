defmodule MiniLineageWeb.Screens do
  @moduledoc """
  Which screen is drawn, and the screens themselves: character creation, the town a character
  stands in and its Gatekeeper, the Chronicles of Ancestry and the error page. `raw/1` renders flashes and lore, which the server
  composes from its own tables and never from anything a player typed.
  """
  use MiniLineageWeb, :html

  import MiniLineageWeb.Controls

  alias MiniLineage.Game.Format
  alias MiniLineageWeb.Paths

  @titles %{
    "start" => "Game Start",
    "gatekeeper" => "Gatekeeper",
    "races" => "Chronicles of Ancestry",
    "error" => "Error"
  }

  @doc "What the panel is headed: the town a run stands in, the screen's name elsewhere."
  def title("town", %{started: true, town: town}), do: town.name
  def title(screen, _view), do: Map.get(@titles, screen, "Mini Lineage")

  def page_title(screen, view), do: "Mini Lineage - #{title(screen, view)}"

  attr :screen, :string, required: true
  attr :view, :map, required: true
  attr :catalog, :map, required: true
  attr :detail, :string, default: nil
  attr :picked, :string, default: nil
  attr :debug, :boolean, default: false
  # Debug builds only: the name game start is already filled in with.
  attr :dev_name, :string, default: nil

  # Another tab can reset the character under the town; draw nothing until `pin_screen/2` moves on.
  def screen(%{view: %{started: false}, screen: screen} = assigns)
      when screen in ~w(town gatekeeper),
      do: ~H||

  def screen(%{screen: "start"} = assigns), do: start_screen(assigns)
  def screen(%{screen: "town"} = assigns), do: town(assigns)
  def screen(%{screen: "gatekeeper"} = assigns), do: gatekeeper(assigns)
  def screen(%{screen: "races"} = assigns), do: races(assigns)
  def screen(assigns), do: error(assigns)

  @doc """
  An action that threw, or the `error` screen. The detail is the thrown message, shown only in a
  debug build: a player is never handed a stack trace.
  """
  attr :view, :map, required: true
  attr :detail, :string, default: nil

  def error(assigns) do
    ~H"""
    <p>An unexpected error occurred on the server, please try again in a moment.</p>
    <.fault detail={@detail} />
    """
  end

  defp start_screen(assigns) do
    ~H"""
    <h2>🐣 A New Bloodline Rises</h2>
    <p>
      The <.link patch={Paths.for_screen("races")}>Chronicles of Ancestry</.link>
      tell of the lineages that walk this realm. Under what name shall the first chapter of your
      dynasty be written, from which ancestry do you hail, and will you take up the blade or the
      staff?
    </p>

    <%!-- `phx-update="ignore"`: the dead render is interactive before the socket connects, and the
          first live render would reset a race picked in that window. --%>
    <form phx-submit="start">
      <div class="form-row" id="start-fields" phx-update="ignore">
        <input
          type="text"
          name="name"
          class="form-input"
          maxlength={MiniLineage.Game.Constants.character().name_max_length}
          placeholder="Enter your name, Heir"
          value={@dev_name}
          autocomplete="off"
          required
        />
        <select name="race_id" class="form-select">
          <option :for={race <- @catalog.races} value={race.id}>{race.emoji} {race.label}</option>
        </select>
        <select name="path" class="form-select">
          <option value="fighter">⚔️ Fighter</option>
          <option value="mystic">🔮 Mystic</option>
        </select>
        <.button type="submit">🚩 Start</.button>
      </div>
    </form>
    """
  end

  # Somewhere to stand, and the way out of it: the systems that fill a town come later.
  defp town(assigns) do
    ~H"""
    <h2>{@view.town.emoji} {@view.town.name}</h2>
    <p>{@view.town.description}</p>
    <%!-- No placeholder: there is no "nowhere" to go, so the first destination is preselected. --%>
    <.select_action
      id="travel-form"
      event="navigate"
      name="place"
      picked={@picked}
      options={[%{value: "gatekeeper", label: "🌀 Gatekeeper"}]}
      default_label="🧭 Travel"
      active_label="🧭 Travel"
      default_variant={:primary}
    />
    """
  end

  # Rules §14: every route out of this town and its fee, then the choice of one.
  defp gatekeeper(assigns) do
    ~H"""
    <p>The Gatekeeper can send you on from {@view.town.emoji} {@view.town.name}, for a fee.</p>
    <.data_table id="routes-table">
      <:col class="name">Destination</:col>
      <:col>Adena</:col>
      <tbody>
        <tr :for={route <- @view.routes} id={"route-#{route.slug}"}>
          <td class="name">
            {route.emoji} {route.name}<span :if={!route.open?} class="muted"> (not open yet)</span>
          </td>
          <td class="adena">🪙 {Format.number(route.fee)}</td>
        </tr>
      </tbody>
    </.data_table>
    <.select_action
      id="teleport-form"
      event="travel"
      name="to"
      picked={@picked}
      placeholder={"🚪 #{@view.town.name}"}
      options={
        Enum.map(@view.routes, fn route ->
          %{
            value: route.slug,
            label: "Teleport to #{route.emoji} #{route.name}",
            disabled?: !route.open?
          }
        end)
      }
      default_label="Return"
      active_label="🌀 Teleport"
    />
    """
  end

  defp attributes,
    do: [
      str: "Strength",
      con: "Constitution",
      dex: "Dexterity",
      int: "Intelligence",
      wit: "Wit",
      men: "Mental Strength"
    ]

  defp races(assigns) do
    ~H"""
    <%!-- No wrapper element: the stylesheet spaces these by sibling order, and a <div> per race
          would break the run. --%>
    <%= for race <- @catalog.races do %>
      <h2>{race.emoji} {race.label}</h2>
      <p>{raw(race.backstory)}</p>
      <.data_table id={"#{race.slug}-classes"}>
        <:col class="name">Class</:col>
        <:col :for={{attr, name} <- attributes()} class="num" title={name}>
          {String.upcase(to_string(attr))}
        </:col>
        <:col class="num" title="Health Points">HP</:col>
        <:col class="num" title="Mana Points">MP</:col>
        <tbody>
          <tr :for={class <- race.classes} id={"class-#{race.slug}-#{class.path}"}>
            <td class="name">{class.name}</td>
            <td :for={{attr, _} <- attributes()} class="num">{class.attributes[attr]}</td>
            <td class="num hp">{class.max_hp}</td>
            <td class="num mp">{class.max_mp}</td>
          </tr>
        </tbody>
      </.data_table>
      <p id={"lineage-#{race.slug}"}>
        {race.perk} They start in {race.town.emoji} {race.town.name}.
      </p>
    <% end %>

    <.back_link started={@view.started} />
    """
  end
end
