defmodule MiniLineageWeb.Screens do
  @moduledoc """
  Which screen is drawn, and the run's own four: Game Start, Town, the Battleground, the ending.
  The pages that outlive a run have modules of their own.

  Markup and class names are carried over from the reference, so the stylesheet applies unchanged.
  `raw/1` renders narratives, which the server composes from the template tables and never from
  anything a player typed.
  """
  use MiniLineageWeb, :html

  import MiniLineageWeb.Controls

  alias MiniLineage.Game.{Access, Narrative}
  alias MiniLineageWeb.Paths
  alias MiniLineageWeb.Screens.{Halls, Record, Shop, Tome}

  # The panel heading and the document title for each screen, carried over verbatim.
  @titles %{
    "start" => "Game Start",
    "home" => "Home Town",
    "inn" => "Inn",
    "weapons" => "Weapon Shop",
    "armors" => "Armor Shop",
    "suicide" => "Commit Suicide",
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

  # A character can be reset from another tab while this one is still showing a screen that needs
  # one. `pin_screen/2` will move us on the next params pass; until then, draw nothing rather than
  # reach into a view that has no character in it.
  @requires_character ~w(home battle weapons armors inn suicide death)

  def screen(%{view: %{started: false}, screen: screen} = assigns)
      when screen in @requires_character,
      do: ~H||

  def screen(%{screen: "start"} = assigns), do: start_screen(assigns)
  def screen(%{screen: "home"} = assigns), do: home(assigns)
  def screen(%{screen: "races"} = assigns), do: races(assigns)
  def screen(%{screen: "battle"} = assigns), do: battle(assigns)

  def screen(%{screen: shop} = assigns) when shop in ~w(inn weapons armors),
    do: Shop.screen(assigns)

  def screen(%{screen: "suicide"} = assigns), do: suicide(assigns)
  def screen(%{screen: "death"} = assigns), do: death(assigns)
  def screen(%{screen: "character"} = assigns), do: Record.screen(assigns)
  def screen(%{screen: "highscores"} = assigns), do: Halls.screen(assigns)
  def screen(%{screen: "statistics"} = assigns), do: Tome.screen(assigns)
  def screen(assigns), do: error(assigns)

  attr :screen, :string, required: true
  attr :record, :map, default: nil
  attr :record_log, :list, default: []

  @doc """
  What a screen puts BELOW the panel rather than inside it. Only the Chronicle so far, and only
  where there is a run to have one — every other screen draws nothing here.
  """
  def aside(%{screen: "character", record: record} = assigns) when record != nil,
    do: Record.chronicle(assigns)

  def aside(assigns), do: ~H||

  @doc """
  Covers both failure modes the reference did: an action that threw, and the modelled `error`
  screen. The detail is the thrown message, and it is shown only in a non-release build — a
  deployed game must never hand a stack trace to a player.
  """
  attr :view, :map, required: true
  attr :detail, :string, default: nil

  def error(assigns) do
    ~H"""
    <p>An unexpected error occurred on the server, please try again in a moment.</p>
    <pre :if={@detail} class="code-block">{@detail}</pre>

    <%!-- Deliberately vague: this screen is reachable started or not, and "safer lands" is true
          of Town and Game Start alike. --%>
    <.back_link started={@view.started} dead={@view.dead} label="Return to safer lands" class="last" />
    """
  end

  # ------------------------------------------------------------------ screens

  defp start_screen(assigns) do
    ~H"""
    <h2>A New Bloodline Rises</h2>
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
          first live render was resetting a race picked in that window back to the first option.
          Nothing here is server-driven — the lineages are static and the name is the player's. --%>
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
        <button type="submit" class="btn">🚩 Start</button>
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
      event="navigate"
      name="to"
      picked={@picked}
      options={[
        %{value: "inn", label: "🍺 Inn"},
        %{value: "armors", label: "🛡️ Armor Shop"},
        %{value: "weapons", label: "🗡️ Weapon Shop"},
        %{value: "battle", label: "💀 Battleground"},
        %{value: "suicide", label: "🥀 Commit Suicide"}
      ]}
      default_label="🧭 Travel"
      active_label={fn value -> if value == "suicide", do: "⚰️ Perish", else: "🧭 Travel" end}
      default_variant="btn"
      active_variant="btn"
    />
    """
  end

  defp races(assigns) do
    ~H"""
    <%!-- No wrapper element: the stylesheet spaces these by sibling order, and a <div> per race
          would break the run. --%>
    <%= for race <- @catalog.races do %>
      <h2>{race.emoji} {race.label}</h2>
      <p>{raw(race.backstory)}</p>
      <p>{raw(race.traits)}</p>
    <% end %>

    <.back_link started={@view.started} dead={@view.dead} />
    """
  end

  defp battle(assigns) do
    ~H"""
    <.battle_narrative :if={@view.last_battle} narrative={@view.last_battle.narrative} />

    <%= if @view.ambushed do %>
      <%!-- The glyph belongs to the line, not to this alert: the Chronicle tells the same line
            later and would otherwise tell it bare. --%>
      <div class="alert alert-danger">
        {raw(
          (@view.last_battle && @view.last_battle.narrative.ambush_line) ||
            "💢 You are being ambushed!"
        )}
      </div>
      <div class="action-links">
        <button type="button" class="btn btn-danger" phx-click="fight">
          ⚔️ {(@view.last_battle && @view.last_battle.narrative.fight_prompt) || "Fight!"}
        </button>
      </div>
    <% else %>
      <p :if={!@view.last_battle}>
        The road out of town is quiet for now. Will you seek out a fight?
      </p>
      <div class="action-links">
        <button type="button" class="btn" phx-click="fight">
          {if @view.last_battle, do: "⚡ #{@view.last_battle.narrative.next_move}", else: "⚔️ Fight!"}
        </button>
        <.link patch={Paths.for_screen("home")} class="btn btn-secondary">Retreat</.link>
      </div>
    <% end %>
    """
  end

  attr :narrative, :map, required: true

  defp battle_narrative(assigns) do
    ~H"""
    <p>
      <span :if={@narrative.crit_line}>{raw(@narrative.crit_line)} </span>{raw(@narrative.kill_line)}
      {raw(@narrative.deflection_line)}
    </p>
    <p>{raw(@narrative.outcome_line)}</p>
    """
  end

  # Going through with it is danger, not primary: red is the last warning before the red death
  # message it leads to. Its emoji trails the label rather than leading it, the one place the game
  # does that.
  defp suicide(assigns) do
    ~H"""
    <p>Do you wish to depart this world?</p>
    <%!-- The two choices carry their own variants, which is why the variant may be a function. --%>
    <.select_action_form
      event="suicide"
      name="confirm"
      picked={@picked}
      options={[
        %{value: "no", label: "No, I changed my mind"},
        %{value: "yes", label: "Yes, stab yourself in the heart"}
      ]}
      default_label="Return"
      active_label={fn value -> if value == "yes", do: "Do it 🥀", else: "Phew 😅" end}
      default_variant="btn-secondary"
      active_variant={fn value -> if value == "yes", do: "btn-danger", else: "btn-secondary" end}
    />
    """
  end

  defp death(assigns) do
    assigns =
      assign(assigns, race: Enum.find(assigns.catalog.races, &(&1.id == assigns.view.race_id)))

    # One ending, however it was reached. A suicide and a heresy are not warnings to be dismissed —
    # they are the last line of the run, and read as one.
    ~H"""
    <p class="hp">{Narrative.death_reason(@view.death_reason, true)}</p>

    <p>{epitaph(@view)}</p>

    <div class="action-links">
      <%!-- Not offered to a run the Hall will not list: the epitaph above has just said so. --%>
      <.link
        :if={@race && not @view.disqualified}
        patch={Paths.for_screen("highscores", @race.slug)}
        class="btn"
      >
        📜 The Hall of {hall_of(@race)} Champions
      </.link>
      <button type="button" class="btn btn-secondary" phx-click="restart">Play Again?</button>
    </div>
    """
  end

  # What the chroniclers did with the run, which is not the same as how it ended. Heresy outranks
  # cowardice, the same order `resolve_death_reason/1` uses.
  defp epitaph(%{cheated: true}),
    do:
      "The scribes have scraped your name from the stone before the ink was dry. Nothing of this " <>
        "run will be kept, and the Hall will not remember you were ever here."

  defp epitaph(%{coward: true}),
    do:
      "No chronicler lifts a quill for a life laid down by its own hand. The pillars stay bare " <>
        "where your name should have stood."

  defp epitaph(_recorded),
    do:
      "The chroniclers have already cut your deeds into the hallowed pillars of Aden, where they " <>
        "keep what the living forget. Your name will echo there long after this road has closed."

  # ---------------------------------------------------------------- the alert

  @doc """
  Whether to warn about low health. Shown wherever HP is on screen, but suppressed on Suicide and
  in the Inn — the Inn's whole call to action already IS "buy food", and the warning would be
  telling you to go where you are standing.
  """
  def low_health_alert?(view, screen) do
    view.started and not view.dead and view.low_health and Access.sidebar?(screen) and
      screen not in ~w(suicide inn)
  end
end
