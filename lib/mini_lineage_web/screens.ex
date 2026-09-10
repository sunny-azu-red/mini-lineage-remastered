defmodule MiniLineageWeb.Screens do
  @moduledoc """
  Every screen, as a function component. Markup and class names are carried over from the
  reference so the stylesheet applies unchanged.

  `raw/1` appears wherever a narrative or flash is rendered. Those strings are always composed by
  the server from the template tables — never from anything a player typed.
  """
  use MiniLineageWeb, :html

  alias MiniLineage.Game.{Access, Format, Narratives}
  alias MiniLineageWeb.Paths

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
    "highscores" => "Hall of Champions",
    "statistics" => "The Tome of Lore",
    "races" => "Chronicles of Ancestry",
    "error" => "Error"
  }

  def title(screen), do: Map.get(@titles, screen, "Mini Lineage")

  def page_title(screen), do: "Mini Lineage - #{title(screen)}"

  # One representative line from the old nine-line pool. Flavour text, not game state.
  @ambush_low_health_line hd(Narratives.ambush_low_health())

  attr :screen, :string, required: true
  attr :view, :map, required: true
  attr :catalog, :map, required: true
  attr :highscores, :list, default: []
  attr :statistics, :map, default: nil
  attr :race_filter, :integer, default: nil
  attr :detail, :string, default: nil
  attr :picked, :string, default: nil

  # A character can be reset from another tab while this one is still showing a screen that needs
  # one. `pin_screen/2` will move us on the next params pass; until then, draw nothing rather than
  # reach into a view that has no character in it.
  @requires_character ~w(home battle weapons armors inn suicide death character)

  def screen(%{view: %{started: false}, screen: screen} = assigns)
      when screen in @requires_character,
      do: ~H||

  def screen(%{screen: "start"} = assigns), do: start_screen(assigns)
  def screen(%{screen: "home"} = assigns), do: home(assigns)
  def screen(%{screen: "races"} = assigns), do: races(assigns)
  def screen(%{screen: "battle"} = assigns), do: battle(assigns)
  def screen(%{screen: "inn"} = assigns), do: shop(inn_assigns(assigns))
  def screen(%{screen: "weapons"} = assigns), do: shop(weapons_assigns(assigns))
  def screen(%{screen: "armors"} = assigns), do: shop(armors_assigns(assigns))
  def screen(%{screen: "suicide"} = assigns), do: suicide(assigns)
  def screen(%{screen: "death"} = assigns), do: death(assigns)
  def screen(%{screen: "character"} = assigns), do: character(assigns)
  def screen(%{screen: "highscores"} = assigns), do: highscores(assigns)
  def screen(%{screen: "statistics"} = assigns), do: statistics(assigns)
  def screen(%{screen: "error"} = assigns), do: error(assigns)
  def screen(assigns), do: error(assigns)

  @doc """
  Covers both failure modes the reference did: an action that threw, and the modelled `error`
  screen. The detail is the thrown message, and it is shown only in a non-release build — a
  deployed game must never hand a stack trace to a player.
  """
  attr :view, :map, required: true
  attr :detail, :string, default: nil

  def error(assigns) do
    assigns = assign_new(assigns, :detail, fn -> nil end)

    ~H"""
    <p>An unexpected error occurred on the server, please try again in a moment.</p>
    <pre :if={@detail} class="code-block">{@detail}</pre>

    <.back_link started={@view.started} label="Return to safer lands" class="last" />
    """
  end

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

  def low_health(assigns) do
    assigns = assign(assigns, ambush_line: @ambush_low_health_line)

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

  attr :started, :boolean, required: true
  attr :label, :string, default: nil
  attr :class, :string, default: "last back"

  def back_link(assigns) do
    ~H"""
    <p class={@class}>
      <.link patch={Paths.for_screen(if @started, do: "home", else: "start")}>
        {@label || if @started, do: "Continue your journey", else: "Go back to game start"}
      </.link>
    </p>
    """
  end

  @doc """
  One `<select>` driving a companion button's label and CSS variant — the shared form behind Town,
  the three shops and Suicide.

  Submitting with the placeholder still selected is a legitimate "go home" signal, so the button is
  never disabled for want of a choice. Until something is picked the button reads `default_label`:
  with no placeholder the first option is pre-selected, but that is the browser choosing, not the
  player, so the button must not yet offer to act on it.
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

    <form phx-submit="start">
      <div class="form-row">
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
      default_label="Travel"
      active_label={fn value -> if value == "suicide", do: "⚰️ Perish", else: "Travel" end}
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

    <.back_link started={@view.started} label="Go back to game start" />
    """
  end

  defp battle(assigns) do
    ~H"""
    <.battle_narrative :if={@view.last_battle} narrative={@view.last_battle.narrative} />

    <%= if @view.ambushed do %>
      <div class="alert alert-danger">
        💢 {raw(
          (@view.last_battle && @view.last_battle.narrative.ambush_line) || "You are being ambushed!"
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
    ~H"""
    <%= if @view.coward || @view.cheated do %>
      <div class="alert alert-danger">{@view.death_reason}</div>
    <% else %>
      <p>{@view.death_reason}</p>
    <% end %>

    <div class="action-links">
      <button :if={@view.highscore_eligible} type="button" class="btn" phx-click="submit_highscore">
        📜 Write your Legacy!
      </button>
      <button type="button" class="btn btn-secondary" phx-click="restart">Play Again?</button>
    </div>
    """
  end

  # -------------------------------------------------------------------- shops

  defp inn_assigns(assigns) do
    assign(assigns,
      type: "food",
      items: assigns.catalog.foods,
      owned_id: nil,
      modifier: %{
        key: :max_health,
        header: "Max HP+",
        title: "Maximum Health Point Increase",
        class: "hp",
        prefix: "+",
        suffix: ""
      },
      stat_header: "HP Heal",
      stat_title: "Health Point Heal",
      action_label: "🪙 Order",
      intro_a: "You have arrived at the Inn.",
      intro_b: "The young lady greets you and sets you at a table."
    )
  end

  defp weapons_assigns(assigns) do
    assign(assigns,
      type: "weapon",
      items: tl(assigns.catalog.weapons),
      owned_id: assigns.view.weapon.id,
      modifier: %{
        key: :crit,
        header: "C. Hit %",
        title: "Critical Hit Chance",
        class: "crit",
        prefix: "",
        suffix: "%"
      },
      stat_header: "P. Attack",
      stat_title: "Physical Attack",
      action_label: "🪙 Purchase",
      intro_a: "You have arrived at the Weapon Shop.",
      intro_b: "The nice man greets you and lets you look through his swords."
    )
  end

  defp armors_assigns(assigns) do
    assign(assigns,
      type: "armor",
      items: tl(assigns.catalog.armors),
      owned_id: assigns.view.armor.id,
      modifier: %{
        key: :regen,
        header: "HP Regen",
        title: "Health Point Regeneration",
        class: "heal",
        prefix: "+",
        suffix: ""
      },
      stat_header: "P. Defense",
      stat_title: "Physical Defense",
      action_label: "🪙 Purchase",
      intro_a: "You have arrived at the Armor Shop.",
      intro_b: "The old man greets you and lets you look through his armors."
    )
  end

  defp shop(assigns) do
    ~H"""
    <p>{@intro_a}<br />{@intro_b}</p>

    <div class="table-container">
      <table class="data-table" style="min-width:400px">
        <thead>
          <tr>
            <th>Name</th>
            <th title={@modifier.title}>{@modifier.header}</th>
            <th title={@stat_title}>{@stat_header}</th>
            <th>Adena</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={item <- @items}>
            <td>{item.emoji} {item.name}</td>
            <td>
              <span :if={(Map.get(item, @modifier.key) || 0) > 0} class={@modifier.class}>
                {@modifier.prefix}{Map.get(item, @modifier.key)}{@modifier.suffix}
              </span>
              <span :if={(Map.get(item, @modifier.key) || 0) <= 0} class="muted">-</span>
            </td>
            <td>{Format.number(item.stat)}</td>
            <td class="gold">🪙 {Format.adena(item.cost)}</td>
          </tr>
        </tbody>
      </table>
    </div>

    <.select_action_form
      event="purchase"
      name="item_id"
      picked={@picked}
      placeholder="🚪 Home Town"
      options={
        Enum.map(@items, fn item ->
          %{
            value: to_string(item.id),
            label: "Pick #{item.emoji} #{item.name}#{if @owned_id == item.id, do: " (Owned)"}",
            disabled?: @owned_id == item.id
          }
        end)
      }
      default_label="Return"
      active_label={@action_label}
    >
      <:hidden><input type="hidden" name="type" value={@type} /></:hidden>
    </.select_action_form>
    """
  end

  # ---------------------------------------------------------------- character

  defp character(assigns) do
    race = Enum.find(assigns.catalog.races, &(&1.id == assigns.view.race_id))
    opponent = Enum.find(assigns.catalog.races, &(&1.id == race.enemy_race_id))
    assigns = assign(assigns, race: race, opponent: opponent)

    ~H"""
    <h2>{@race.emoji} {@view.name} of {@race.label} Ancestry</h2>
    <p>{raw(@race.backstory)}</p>
    <p>{raw(@race.traits)}</p>

    <h2>Inventory &amp; Stats</h2>
    <p>
      You are wielding the {@view.weapon.emoji} {@view.weapon.name} granting
      <span class="hp">
        <span id="char-stat-attack">{Format.number(@view.stats.attack)}</span> Physical Attack
      </span>
      <%= if (@view.weapon.crit || 0) > 0 do %>
        and <span class="crit">+{@view.weapon.crit}% Critical Hit Chance</span>
      <% end %>, and wearing
      the {@view.armor.emoji} {@view.armor.name} providing
      <span class="muted">
        <span id="char-stat-defense">{Format.number(@view.stats.defense)}</span> Physical Defense
      </span>
      <%= if (@view.armor.regen || 0) > 0 do %>
        and <span class="heal">+{@view.armor.regen} HP Regeneration</span>
      <% end %>.
    </p>
    <p>
      Combined with your ancestry, you strike with a total of
      <span class="crit">
        <span id="char-stat-crit">{Format.number(@view.stats.crit)}</span>% Critical Hit Chance
      </span>
      and mend wounds at
      <span class="heal">
        +<span id="char-stat-regen">{Format.number(@view.stats.regen)}</span> HP Regeneration
      </span>
      per rest cycle, while navigating the roads with a <span class="muted">
        <span id="char-stat-ambush">{Format.number(@view.stats.ambush_risk)}</span>% Ambush Risk
      </span>.
    </p>

    <h2>The Journey So Far</h2>
    <p>
      Your journey across the realm has been defined by conflict and survival. You have fought through <span class="gold">{Format.pluralize("battle", "battles", @view.counters.total_battles)}</span>, slaying
      <span class="gold">
        {Format.pluralize(
          @opponent.label,
          @opponent.plural,
          @view.counters.total_enemies_killed,
          @opponent.emoji
        )}
      </span>
      and overcoming
      <span class="hp">
        {Format.pluralize("cunning ambush", "cunning ambushes", @view.counters.total_ambushes)}
      </span>
      along the road.
    </p>
    <%!-- The hook animates every [data-value] beneath it, so the HP figure counts as it regenerates. --%>
    <p id="char-vitality" phx-hook="AnimatedValues">
      Experience wise, you are at <span class="gold">Level {Format.number(@view.level)}</span>
      with a
      total of <span class="xp">{Format.number(@view.experience)} XP</span>
      <%= if @view.is_max_level do %>
        , standing unchallenged at the zenith of martial prowess
      <% else %>
        , requiring another <span class="xp">{Format.number(@view.xp_needed)} XP</span>
        to reach <span class="gold">Level {Format.number(@view.level + 1)}</span>
      <% end %>
      and your vitality currently sustains you at
      <span class="hp">
        <span id="char-hp" class="animate-val" data-key="char-hp" data-value={@view.health}>{Format.number(
          @view.health
        )}</span>
        / <span id="char-max-hp">{Format.number(@view.max_health)}</span>
        HP
      </span>
      while your purse holds <span class="gold">🪙 {Format.adena(@view.adena)} Adena</span>
      for the
      journey ahead.
    </p>

    <.back_link started={@view.started} />
    """
  end

  # --------------------------------------------------------------- highscores

  defp highscores(assigns) do
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

    <%= if @highscores == [] do %>
      <p>
        The halls are silent. No soul has yet earned a place among these hallowed pillars. The
        chronicle of champions awaits its first entry. Will your name be the first to echo through
        eternity?
      </p>
    <% else %>
      <div class="table-container">
        <table class="data-table" style="min-width:545px">
          <thead>
            <tr>
              <th>Name</th>
              <th class="center">Level</th>
              <th>Total XP</th>
              <th>Wealth</th>
              <th>Date</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={row <- @highscores}>
              <td>{race_emoji(@catalog, row.race_id)} {String.slice(row.name, 0, 20)}</td>
              <td class="center">{Format.number(row.level)}</td>
              <td class="xp">{Format.number(row.total_xp)}</td>
              <td class="gold">🪙 {Format.adena(row.adena)}</td>
              <td class="muted">{short_date(row.created)}</td>
            </tr>
          </tbody>
        </table>
      </div>
    <% end %>

    <.back_link started={@view.started} class="last" />
    """
  end

  # --------------------------------------------------------------- statistics

  defp statistics(assigns) do
    ~H"""
    <%= if @statistics do %>
      <h2>The Legacy of the Realm</h2>
      <p>
        In the age of steel and magic,
        <span class="gold">{Format.pluralize("Brave Soul", "Brave Souls", @statistics.total_players)}</span>
        {verb(@statistics.total_players, "has", "have")} set foot upon these dangerous lands. Through
        hardship and triumph, they have collectively ascended
        <span class="gold">{Format.pluralize("Level", "Levels", @statistics.total_levels_gained)}</span>
        in their pursuit of power. Yet, glory always exacts a price, because
        <span class="hp">{Format.pluralize("Champion", "Champions", @statistics.total_deaths)}</span>
        {verb(@statistics.total_deaths, "has", "have")} fallen in battle... lost, but not forgotten.
      </p>
      <p>
        A few, overwhelmed by the weight of their journey, chose the coward's end, with
        <span class="muted">
          {Format.pluralize("Weak Soul", "Weak Souls", @statistics.total_players_suicided)}
        </span>
        taking {verb(@statistics.total_players_suicided, "its own life", "their own lives")}, while
        <span class="hp">{Format.pluralize("Heretic", "Heretics", @statistics.total_players_cheated)}</span>
        {verb(@statistics.total_players_cheated, "was", "were")} struck down by the gods for attempting
        to bypass the laws of the realm.
      </p>

      <h2>Echoes of the Battlefield</h2>
      <p>
        The drums of war never truly fall silent because
        <span class="gold">{Format.pluralize("Battle", "Battles", @statistics.total_battles)}</span>
        {verb(@statistics.total_battles, "has", "have")} been fought against the encroaching darkness,
        resulting in the defeat of
        <span class="gold">
          {Format.pluralize("Formidable Foe", "Formidable Foes", @statistics.total_enemies_killed)}
        </span>
        through lethal precision and
        <span class="crit">
          {Format.pluralize("Critical Strike", "Critical Strikes", @statistics.total_critical_hits)}
        </span>
        that turned the tide of every skirmish.
      </p>
      <p>
        From these conflicts, the survivors extracted vast wisdom, gaining a total of <span class="xp">{Format.number(@statistics.total_xp_gained)} XP</span>. But the wild is
        treacherous, as the hunters became the hunted and
        <span class="hp">{Format.pluralize("Ambush", "Ambushes", @statistics.total_ambushes)}</span>
        {verb(@statistics.total_ambushes, "has", "have")} occurred, nearly claiming those who walked
        unprepared.
      </p>

      <h2>The Toll of Survival</h2>
      <p>
        Hardship is measured in blood and resilience. Our champions have shed <span class="hp">{Format.number(@statistics.total_hp_lost)} HP</span>, flesh torn by tooth and
        claw. Yet, the craft of the blacksmith has proven its worth, as armor deflected <span class="muted">{Format.number(@statistics.total_damage_blocked)} Damage</span>.
      </p>
      <p>
        To mend their broken bodies, they have sought the warmth of the Inn and the delicious food
        inside, healing for a combined total of <span class="heal">{Format.number(@statistics.total_hp_healed)} HP</span>. In the stillness of
        sanctuary, where fine armor protects the weary, another
        <span class="heal">{Format.number(@statistics.total_hp_regen)} HP</span>
        was restored through the natural mending of the soul.
      </p>

      <h2>The Flow of Fortune</h2>
      <p>
        Wealth flows like a river through the pockets of the daring. A massive sum of
        <span class="gold">🪙 {Format.adena(@statistics.total_adena_generated)} Adena</span>
        has been pulled from the corpses of monsters and the hidden corners of the world. Most of this
        fortune, however, returns to the realm's economy since
        <span class="gold">🪙 {Format.adena(@statistics.total_adena_spent)} Adena</span>
        has been spent on provisions and equipment.
      </p>
      <p>
        The shops have flourished, selling
        <span class="gold">{Format.pluralize("Weapon", "Weapons", @statistics.total_weapons_bought)}</span>
        and
        <span class="gold">{Format.pluralize("Armor", "Armors", @statistics.total_armors_bought)}</span>
        to those who would be king, while the local Inn has served
        <span class="gold">{Format.pluralize("Meal", "Meals", @statistics.total_food_bought)}</span>
        to keep the fires of life burning.
      </p>
    <% else %>
      <p>
        The ancient archives are empty and the lore of the realm has been lost to time. The chronicles
        of the realm await their first dynasty. Will you be the one to start a new bloodline?
      </p>
    <% end %>

    <.back_link started={@view.started} label="Go back to game start" />
    """
  end

  # ---------------------------------------------------------------- helpers

  defp verb(1, singular, _plural), do: singular
  defp verb(_count, _singular, plural), do: plural

  defp race_emoji(catalog, race_id) do
    case Enum.find(catalog.races, &(&1.id == race_id)) do
      nil -> "❓"
      race -> race.emoji
    end
  end

  defp short_date(%NaiveDateTime{} = at) do
    pad = &String.pad_leading(Integer.to_string(&1), 2, "0")

    "#{pad.(at.day)}/#{pad.(at.month)}/#{String.slice(Integer.to_string(at.year), -2..-1)}, " <>
      "#{pad.(at.hour)}:#{pad.(at.minute)}"
  end

  def sidebar?(screen), do: Access.sidebar?(screen)

  @doc """
  Whether to warn about low health. Shown wherever HP is on screen, but suppressed on Suicide and
  in the Inn — the Inn's whole call to action already IS "buy food", and the warning would be
  telling you to go where you are standing.
  """
  def low_health_alert?(view, screen) do
    view.started and not view.dead and view.low_health and sidebar?(screen) and
      screen not in ~w(suicide inn)
  end
end
