defmodule MiniLineageWeb.Screens do
  @moduledoc """
  Which screen is drawn, and the small ones drawn here; the big pages have modules of their own.
  `raw/1` renders narratives, which the server composes from the template tables and never from
  anything a player typed.
  """
  use MiniLineageWeb, :html

  import MiniLineageWeb.Controls

  alias MiniLineage.Game.{Access, Classes, Formulas, Narrative}
  alias MiniLineageWeb.Paths
  alias MiniLineageWeb.Screens.{Halls, Record, Shop, SymbolMaker, Tome}

  @titles %{
    "start" => "Game Start",
    "home" => "Home Town",
    "inn" => "Inn",
    "weapons" => "Weapon Shop",
    "armors" => "Armor Shop",
    "class_master" => "Class Master",
    "symbol_maker" => "Symbol Maker",
    "battle" => "Battleground",
    "death" => "Game Over",
    "character" => "Character",
    "statistics" => "The Tome of Lore",
    "races" => "Chronicles of Ancestry",
    "error" => "Error"
  }

  def title(screen, race \\ nil)
  def title("highscores", race), do: "Hall of #{hall_of(race)} Champions"
  def title(screen, _race), do: Map.get(@titles, screen, "Mini Lineage")

  def page_title(screen, race \\ nil), do: "Mini Lineage - #{title(screen, race)}"

  attr :screen, :string, required: true
  attr :view, :map, required: true
  attr :catalog, :map, required: true
  attr :boards, :map, default: %{}
  attr :character_id, :string, default: nil
  attr :record, :map, default: nil
  attr :record_view, :map, default: nil
  attr :from, :string, default: nil
  attr :statistics, :map, default: nil
  attr :race_filter, :integer, default: nil
  attr :detail, :string, default: nil
  attr :picked, :string, default: nil
  attr :sorts, :map, default: %{}

  # Another tab can reset the character under a screen that needs one; draw nothing until
  # `pin_screen/2` moves us on the next params pass.
  @requires_character ~w(home battle weapons armors inn class_master symbol_maker death)

  def screen(%{view: %{started: false}, screen: screen} = assigns)
      when screen in @requires_character,
      do: ~H||

  def screen(%{screen: "start"} = assigns), do: start_screen(assigns)
  def screen(%{screen: "home"} = assigns), do: home(assigns)
  def screen(%{screen: "races"} = assigns), do: races(assigns)
  def screen(%{screen: "battle"} = assigns), do: battle(assigns)

  def screen(%{screen: shop} = assigns) when shop in ~w(inn weapons armors),
    do: Shop.screen(assigns)

  def screen(%{screen: "class_master"} = assigns), do: class_master(assigns)
  def screen(%{screen: "symbol_maker"} = assigns), do: SymbolMaker.screen(assigns)
  def screen(%{screen: "death"} = assigns), do: death(assigns)
  def screen(%{screen: "character"} = assigns), do: Record.screen(assigns)
  def screen(%{screen: "highscores"} = assigns), do: Halls.screen(assigns)
  def screen(%{screen: "statistics"} = assigns), do: Tome.screen(assigns)
  def screen(assigns), do: error(assigns)

  attr :screen, :string, required: true
  attr :record, :map, default: nil
  attr :record_log, :list, default: []
  attr :record_log_older, :boolean, default: false
  attr :character_id, :string, default: nil

  @doc """
  What a screen puts BESIDE the panel rather than inside it. `aside?/2` says whether there is
  anything to draw, since the column and the page's width go with it.
  """
  def aside(assigns) do
    assigns = assign(assigns, mine: assigns.record.id == assigns.character_id)

    ~H"""
    <Record.chronicle
      record_log={@record_log}
      record_id={@record.id}
      older={@record_log_older}
      mine={@mine}
    />
    """
  end

  @doc "The columns a table sorts on, by its id, or nil for a table that does not sort."
  def sorts("halls-table"), do: Halls.sorts()
  def sorts(_table), do: nil

  def aside?("character", record), do: record != nil
  def aside?(_screen, _record), do: false

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

  # ------------------------------------------------------------------ screens

  defp start_screen(assigns) do
    ~H"""
    <h2>🐣 A New Bloodline Rises</h2>
    <p>
      Will you forge a fresh path, or honor the ancestors resting within the <.link patch={
        Paths.for_screen("highscores")
      }>Hall of Champions</.link>? Blood, gold, and glory
      are etched in <.link patch={Paths.for_screen("statistics")}>The Tome of Lore</.link>, while the
      <.link patch={Paths.for_screen("races")}>Chronicles of Ancestry</.link>
      detail the unique traits
      of the lineages that walk this realm.
    </p>
    <p>
      Under what name shall the first chapter of your dynasty be written, and from which ancestry do
      you hail?
    </p>

    <%!-- `phx-update="ignore"`: the dead render is interactive before the socket connects, and the
          first live render would reset a race picked in that window. --%>
    <form phx-submit="start">
      <div class="form-row" id="start-fields" phx-update="ignore">
        <input
          type="text"
          name="name"
          class="form-input"
          maxlength="20"
          placeholder="Enter your name, Heir"
          autocomplete="off"
          required
        />
        <select name="race_id" class="form-select">
          <option :for={race <- @catalog.races} value={race.id}>{race.emoji} {race.label}</option>
        </select>
        <select name="archetype" class="form-select">
          <option value="fighter">⚔️ Fighter</option>
          <option value="mystic">🔮 Mystic</option>
        </select>
        <.button type="submit">🚩 Start</.button>
      </div>
    </form>
    """
  end

  defp home(assigns) do
    ~H"""
    <p>
      Welcome to <.link patch={Paths.for_screen("highscores")}>City of Aden</.link>.<br />
      Where do you want to go next, or what do you want to do?
    </p>

    <%!-- No placeholder: there is no "nowhere" to travel to, so the first destination is preselected. --%>
    <.select_action_form
      id="travel-form"
      event="navigate"
      name="to"
      picked={@picked}
      options={[
        %{value: "inn", label: "🍺 Inn"},
        %{value: "armors", label: "🛡️ Armor Shop"},
        %{value: "weapons", label: "🗡️ Weapon Shop"},
        %{value: "class_master", label: "📜 Class Master"},
        %{value: "symbol_maker", label: "🖋️ Symbol Maker"},
        %{value: "battle", label: "💀 Battleground"}
      ]}
      default_label="🧭 Travel"
      active_label="🧭 Travel"
      default_variant={:primary}
    />
    """
  end

  defp attributes, do: ~w(str con dex int wit men)a

  # A calling's table matches the run's own through the transfer, so what it changes is what each
  # level adds from there: shown for the run's next level, with the attributes it has now.
  defp class_master(assigns) do
    class = Classes.get(assigns.view.class_id)
    callings = Classes.children(class.id)
    stats = assigns.view.stats

    assigns =
      assign(assigns,
        class: class,
        opens_at: callings |> Enum.map(& &1.level) |> Enum.min(fn -> nil end),
        callings:
          Enum.map(callings, fn calling ->
            level = min(max(assigns.view.level, calling.level), 79)

            gain = fn table, bonus ->
              bonus.(table.(calling.id, level + 1)) - bonus.(table.(calling.id, level))
            end

            %{
              class: calling,
              hp_gain: gain.(&Classes.hp/2, &Formulas.max_hp(&1, stats.con)),
              mp_gain: gain.(&Classes.mp/2, &Formulas.max_mp(&1, stats.men))
            }
          end)
      )

    ~H"""
    <p>
      The Class Master looks you over, a <span class="level">{@class.name}</span>
      at <span class="level">Level {@view.level}</span>.
    </p>

    <%= cond do %>
      <% @callings == [] -> %>
        <p>There is no calling past yours that the Class Master can teach.</p>
        <.back_link started={@view.started} dead={@view.dead} />
      <% true -> %>
        <p :if={@view.level < @opens_at}>
          Your next calling opens at <span class="level">Level {@opens_at}</span>, so come back then.
          This is what each would add to you with every level after it.
        </p>
        <p :if={@view.level >= @opens_at}>
          Choose your calling. It cannot be undone, and it decides how much each level adds from here.
        </p>

        <.data_table id="class-table">
          <:col class="name">Calling</:col>
          <:col class="num" title="Max HP each level adds">HP per Level</:col>
          <:col class="num" title="Max MP each level adds">MP per Level</:col>
          <tbody>
            <tr :for={calling <- @callings} id={"calling-#{calling.class.id}"}>
              <td class="name">{calling.class.name}</td>
              <td class="num hp">+{calling.hp_gain}</td>
              <td class="num mp">+{calling.mp_gain}</td>
            </tr>
          </tbody>
        </.data_table>

        <.select_action_form
          id="transfer-form"
          event="transfer"
          name="class_id"
          picked={@picked}
          placeholder="🚪 Home Town"
          options={
            Enum.map(@callings, fn calling ->
              %{
                value: to_string(calling.class.id),
                label: "Become #{calling.class.name}",
                disabled?: @view.level < calling.class.level
              }
            end)
          }
          default_label="Return"
          active_label="📜 Transfer"
        />
    <% end %>
    """
  end

  defp races(assigns) do
    ~H"""
    <%!-- No wrapper element: the stylesheet spaces these by sibling order, and a <div> per race
          would break the run. --%>
    <%= for race <- @catalog.races do %>
      <h2>{race.emoji} {race.label}</h2>
      <p>{raw(race.backstory)}</p>
      <.data_table id={"#{race.slug}-classes"}>
        <:col class="name">Class</:col>
        <:col :for={attr <- attributes()} class="num">{String.upcase(to_string(attr))}</:col>
        <:col class="num" title="Maximum HP at level 1">HP</:col>
        <:col class="num" title="Maximum MP at level 1">MP</:col>
        <tbody>
          <tr :for={class <- race.classes} id={"class-#{class.id}"}>
            <td class="name">{class.name}</td>
            <td :for={attr <- attributes()} class="num">{class.attributes[attr]}</td>
            <td class="num hp">{class.max_hp}</td>
            <td class="num mp">{class.max_mp}</td>
          </tr>
        </tbody>
      </.data_table>
    <% end %>

    <.back_link started={@view.started} dead={@view.dead} />
    """
  end

  defp battle(assigns) do
    ~H"""
    <.battle_narrative :if={@view.last_battle} narrative={@view.last_battle.narrative} />

    <p :if={!@view.last_battle}>
      The road out of town is quiet for now. Will you seek out a fight?
    </p>
    <div class="action-links">
      <.button phx-click="fight">
        {if @view.last_battle, do: "⚡ #{@view.last_battle.narrative.next_move}", else: "⚔️ Fight!"}
      </.button>
      <.button variant={:secondary} patch={Paths.for_screen("home")}>Retreat</.button>
    </div>
    """
  end

  attr :narrative, :map, required: true

  defp battle_narrative(assigns) do
    ~H"""
    <p>
      <%!-- Always "you": the fighter reading their own fight, where a record's reader gets "they". --%>
      <span :if={@narrative.crit_line}>{raw(Narrative.voiced(@narrative.crit_line, true))} </span>{raw(
        Narrative.voiced(@narrative.kill_line, true)
      )}
      {raw(Narrative.voiced(@narrative.deflection_line, true))}
    </p>
    <p>{raw(Narrative.voiced(@narrative.outcome_line, true))}</p>
    """
  end

  defp death(assigns) do
    assigns =
      assign(assigns, race: Enum.find(assigns.catalog.races, &(&1.id == assigns.view.race_id)))

    # One ending, however it was reached. A heresy is not a warning to be dismissed: it is the last
    # line of the run, and reads as one.
    ~H"""
    <%!-- On a SPAN inside the paragraph, not on the paragraph: the weight rule reaches a value
          sitting inside a sentence, so `p.deaths` takes the colour without it. --%>
    <p><span class="deaths">{Narrative.death_reason(@view.death_reason, true)}</span></p>

    <p>{epitaph(@view)}</p>

    <div class="action-links">
      <%!-- Not offered to a run the Hall will not list: the epitaph above has just said so. --%>
      <.button
        :if={@race && not @view.disqualified}
        patch={Paths.for_screen("highscores", @race.slug)}
      >
        📜 The Hall of {hall_of(@race)} Champions
      </.button>
      <.button variant={:secondary} phx-click="restart">Play Again?</.button>
    </div>
    """
  end

  # What the chroniclers did with the run, which is not the same as how it ended.
  defp epitaph(%{cheated: true}),
    do:
      "The scribes have scraped your name from the stone before the ink was dry. Nothing of this " <>
        "run will be kept, and the Hall will not remember you were ever here."

  defp epitaph(_recorded),
    do:
      "The chroniclers have already cut your deeds into the hallowed pillars of Aden, where they " <>
        "keep what the living forget. Your name will echo there long after this road has closed."

  # ---------------------------------------------------------------- the alert

  @doc """
  Whether to warn about low health: wherever HP is on screen, but not in the Inn, where it would
  tell you to go where you are standing.
  """
  def low_health_alert?(view, screen) do
    view.started and not view.dead and view.low_health and Access.sidebar?(screen) and
      screen != "inn"
  end
end
