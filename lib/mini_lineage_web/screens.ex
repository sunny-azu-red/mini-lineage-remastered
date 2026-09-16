defmodule MiniLineageWeb.Screens do
  @moduledoc """
  Every screen, as a function component. Markup and class names are carried over from the
  reference so the stylesheet applies unchanged.

  `raw/1` appears wherever a narrative or flash is rendered. Those strings are always composed by
  the server from the template tables — never from anything a player typed.
  """
  use MiniLineageWeb, :html

  alias MiniLineage.Game.{Access, Format}
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

  attr :screen, :string, required: true
  attr :view, :map, required: true
  attr :catalog, :map, required: true
  attr :boards, :map, default: %{}
  attr :character_id, :string, default: nil
  attr :record, :map, default: nil
  attr :record_view, :map, default: nil
  attr :record_log, :list, default: []
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

    <%!-- Deliberately vague: this screen is reachable started or not, and "safer lands" is true
          of Town and Game Start alike. --%>
    <.back_link started={@view.started} dead={@view.dead} label="Return to safer lands" class="last" />
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

  attr :started, :boolean, required: true
  attr :dead, :boolean, default: false
  attr :label, :string, default: nil
  attr :class, :string, default: "last back"
  # Named outright where "where you came from" is neither Town nor Game Start.
  attr :to, :string, default: nil

  def back_link(assigns) do
    ~H"""
    <p class={@class}>
      <.link patch={Paths.for_screen(@to || whence(@started, @dead))}>
        {@label || whence_label(@started, @dead)}
      </.link>
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

  @doc """
  One `<select>` driving a companion button's label and variant — the shared form behind Town, the
  shops and Suicide. Submitting with the placeholder selected is a legitimate "go home", so the
  button is never disabled; until the PLAYER picks, it reads `default_label`.
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

    <.back_link started={@view.started} dead={@view.dead} />
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
    assigns =
      assign(assigns, race: Enum.find(assigns.catalog.races, &(&1.id == assigns.view.race_id)))

    # One ending, however it was reached. A suicide and a heresy are not warnings to be dismissed —
    # they are the last line of the run, and read as one.
    ~H"""
    <p>{@view.death_reason}</p>

    <p class="muted">{epitaph(@view)}</p>

    <div class="action-links">
      <.link :if={@race} patch={Paths.for_screen("highscores", @race.slug)} class="btn">
        {@race.emoji} The Hall of {@race.plural}
      </.link>
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

  attr :view, :map, required: true
  attr :catalog, :map, required: true
  attr :entry, :map, default: nil
  attr :chronicle, :list, default: []
  attr :mine, :boolean, default: true

  @doc false
  # One record, whoever is reading it. `mine` switches the voice: yours speaks to you, anybody
  # else's speaks about them. The verbs never move — they/them takes the same forms as you.
  def record(assigns) do
    race = Enum.find(assigns.catalog.races, &(&1.id == assigns.view.race_id))
    opponent = Enum.find(assigns.catalog.races, &(&1.id == race.enemy_race_id))

    # Numbers named up here so each stat and its punctuation fit on one line below. The HEEx
    # formatter breaks a long line at a tag boundary, and a newline there renders as a space —
    # which is how "Physical Defense ." happens.
    assigns =
      assign(assigns,
        race: race,
        opponent: opponent,
        dead: assigns.view.dead,
        voice: voice(assigns.mine),
        attack: Format.number(assigns.view.stats.attack),
        defense: Format.number(assigns.view.stats.defense),
        crit: Format.number(assigns.view.stats.crit),
        regen: Format.number(assigns.view.stats.regen),
        ambush: Format.number(assigns.view.stats.ambush_risk),
        level: Format.number(assigns.view.level),
        next_level: Format.number(assigns.view.level + 1),
        experience: Format.number(assigns.view.experience),
        xp_needed: Format.number(assigns.view.xp_needed),
        purse: Format.adena(assigns.view.adena)
      )

    # The numbers are shared, so a living and a fallen character can never drift apart; only the
    # tense moves. The closing section forks outright — its sentences change shape, not just verbs,
    # since there is no next level to reach and no journey ahead.
    ~H"""
    <h2>{@race.emoji} {@view.name} of {@race.label} Ancestry</h2>
    <p>{raw(@race.backstory)}</p>
    <p>{raw(@race.traits)}</p>

    <h2>Inventory &amp; Stats</h2>
    <p phx-no-format>
      {@voice.they} {if @dead, do: "were wielding", else: "are wielding"} the {@view.weapon.emoji} {@view.weapon.name} granting
      <span class="hp"><span id="char-stat-attack">{@attack}</span> Physical Attack</span><%= if (@view.weapon.crit || 0) > 0 do %> and <span class="crit">+{@view.weapon.crit}% Critical Hit Chance</span><% end %>, and {if @dead, do: "wore", else: "wearing"} the {@view.armor.emoji} {@view.armor.name} providing
      <span class="muted"><span id="char-stat-defense">{@defense}</span> Physical Defense</span><%= if (@view.armor.regen || 0) > 0 do %> and <span class="heal">+{@view.armor.regen} HP Regeneration</span><% end %>.
    </p>
    <p>
      Combined with {@voice.their} ancestry, {@voice.them} {if @dead, do: "struck", else: "strike"} with a total of
      <span class="crit"><span id="char-stat-crit">{@crit}</span>% Critical Hit Chance</span>
      and {if @dead, do: "mended", else: "mend"} wounds at
      <span class="heal">+<span id="char-stat-regen">{@regen}</span> HP Regeneration</span>
      per rest cycle, while navigating the roads with a <span class="muted"><span id="char-stat-ambush">{@ambush}</span>% Ambush Risk</span>.
    </p>

    <%= if @dead do %>
      <h2>{@voice.whose} Journey Has Ended</h2>
      <p>
        {@voice.whose} journey across the realm was defined by conflict and survival. {@voice.they} fought through <span class="gold">{Format.pluralize("battle", "battles", @view.counters.total_battles)}</span>, slaying
        <span class="gold">{Format.pluralize(
          @opponent.label,
          @opponent.plural,
          @view.counters.total_enemies_killed,
          @opponent.emoji
        )}</span>
        <%= if @view.counters.total_ambushes > 0 do %>
          and overcoming
          <span class="hp">{Format.pluralize(
            "cunning ambush",
            "cunning ambushes",
            @view.counters.total_ambushes
          )}</span>
        <% end %>
        along the road.
      </p>
      <p phx-no-format>
        {@voice.they} fell at <span class="gold">Level {@level}</span>
        with a total of <span class="xp">{@experience} XP</span><%= if @view.is_max_level do %>, standing unchallenged at the zenith of martial prowess<% else %>, <span class="xp">{@xp_needed} XP</span> short of <span class="gold">Level {@next_level}</span><% end %>, and {@voice.their} purse held <span class="gold">🪙 {@purse} Adena</span>
        when the road ran out.
      </p>
      <p>{@view.death_reason}</p>
    <% else %>
      <h2>The Journey So Far</h2>
      <p>
        {@voice.whose} journey across the realm has been defined by conflict and survival. {@voice.they} have fought through <span class="gold">{Format.pluralize("battle", "battles", @view.counters.total_battles)}</span>, slaying
        <span class="gold">{Format.pluralize(
          @opponent.label,
          @opponent.plural,
          @view.counters.total_enemies_killed,
          @opponent.emoji
        )}</span>
        <%= if @view.counters.total_ambushes > 0 do %>
          and overcoming
          <span class="hp">{Format.pluralize(
            "cunning ambush",
            "cunning ambushes",
            @view.counters.total_ambushes
          )}</span>
        <% end %>
        along the road.
      </p>
      <%!-- The hook animates every [data-value] beneath it, so the HP figure counts as it regenerates. --%>
      <p id="char-vitality" phx-hook="AnimatedValues" phx-no-format>
        Experience wise, {@voice.them} are at <span class="gold">Level {@level}</span>
        with a total of <span class="xp">{@experience} XP</span><%= if @view.is_max_level do %>, standing unchallenged at the zenith of martial prowess<% else %>, requiring another <span class="xp">{@xp_needed} XP</span> to reach <span class="gold">Level {@next_level}</span><% end %>
        and {@voice.their} vitality currently sustains {@voice.object} at
        <span class="hp"><span
          id="char-hp"
          class="animate-val"
          data-key="char-hp"
          data-value={@view.health}
        >{Format.number(@view.health)}</span>
        / <span id="char-max-hp">{Format.number(@view.max_health)}</span>
        HP</span>
        while {@voice.their} purse holds <span class="gold">🪙 {@purse} Adena</span>
        for the journey ahead.
      </p>
    <% end %>

    <p :if={@entry && @entry.disqualified} class="muted">
      Barred from the Halls of Champions — this run ended by its own hand or by heresy. Its record
      stands regardless.
    </p>

    <p :if={@entry} phx-no-format>
      Set out on <.stamp id="record-set-out" at={@entry.inserted_at} />
      {ending(@entry)} <.stamp id="record-last" at={@entry.updated_at} />.
    </p>

    <h3>The Chronicle</h3>

    <%= if @chronicle == [] do %>
      <p>Not one blow struck. This tale is over before it began.</p>
    <% else %>
      <ol class="chronicle">
        <li :for={fight <- @chronicle}>{raw(fight.narrative.outcome_line)}</li>
      </ol>
    <% end %>
    """
  end

  # Your own page speaks to you; somebody else's speaks about them. They/them is not only the right
  # default for a character whose gender the game never records — it also takes the same verb forms
  # as "you", so nothing but the pronouns moves between the two.
  defp voice(true),
    do: %{they: "You", them: "you", object: "you", their: "your", whose: "Your"}

  defp voice(false),
    do: %{they: "They", them: "they", object: "them", their: "their", whose: "Their"}

  defp character(%{record: nil} = assigns) do
    ~H"""
    <p>
      No such name is written here. The Halls keep only those who drew a blade, and this one either
      never did or was never real.
    </p>

    <.halls_link />
    """
  end

  defp character(assigns) do
    ~H"""
    <.record
      view={@record_view}
      catalog={@catalog}
      entry={@record}
      chronicle={@record_log}
      mine={@record.id == @character_id}
    />

    <%!-- Back the way you came: the sidebar says so, the Halls say nothing and are the default. --%>
    <%= if @from == "game" do %>
      <.back_link started={@view.started} dead={@view.dead} />
    <% else %>
      <.halls_link />
    <% end %>
    """
  end

  defp halls_link(assigns) do
    ~H"""
    <p class="last back">
      <.link patch={Paths.for_screen("highscores")}>Go back to halls of champions</.link>
    </p>
    """
  end

  # --------------------------------------------------------------- highscores

  defp highscores(assigns) do
    assigns = assign(assigns, rows: Map.get(assigns.boards, assigns.race_filter, []))

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
            <.character_row
              :for={row <- @rows}
              catalog={@catalog}
              row={row}
              mine={row.id == @character_id}
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

  defp character_row(assigns) do
    ~H"""
    <tr class={["character-row", still_going?(@row) && "alive", @mine && "mine"]}>
      <td>
        {race_emoji(@catalog, @row.race_id)}
        <.link patch={Paths.for_character(@row.id)}>{String.slice(@row.name || "", 0, 20)}</.link>
        <span :if={@row.online} class="online" title="Online right now">•</span>
        <span :if={@row.medal} title={medal_title(@row.medal)}>{medal(@row.medal)}</span>
      </td>
      <td class="center">{Format.number(@row.level)}</td>
      <td class="xp">{Format.number(@row.total_xp)}</td>
      <td class="gold">🪙 {Format.adena(@row.adena)}</td>
      <td class="muted"><.stamp id={"seen-#{@row.id}"} at={@row.updated_at} /></td>
    </tr>
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

    <.back_link started={@view.started} dead={@view.dead} />
    """
  end

  # ---------------------------------------------------------------- helpers

  defp verb(1, singular, _plural), do: singular
  defp verb(_count, _singular, plural), do: plural

  # A run is going while it has neither died nor lost its session. Without one it is missing: it
  # can never be played again, so it is over even though it never died.
  defp still_going?(row), do: not row.dead and row.active

  # What the chroniclers did with the run, which is not the same as how it ended. Heresy outranks
  # cowardice, the same order `resolve_death_reason/1` uses.
  defp epitaph(%{cheated: true}),
    do:
      "The scribes have scraped your name from the stone before the ink was dry. Nothing of this " <>
        "run will be kept, and the Halls will not remember you were ever here."

  defp epitaph(%{coward: true}),
    do:
      "No chronicler lifts a quill for a life laid down by its own hand. The pillars stay bare " <>
        "where your name should have stood."

  defp epitaph(_recorded),
    do:
      "The chroniclers have already cut your deeds into the hallowed pillars of Aden, where they " <>
        "keep what the living forget. Your name will echo there long after this road has closed."

  defp medal(1), do: "🥇"
  defp medal(2), do: "🥈"
  defp medal(3), do: "🥉"

  # Three ways a record ends: fallen, still going, or missing — walked away from and past the day
  # anyone could pick it up again.
  defp ending(%{dead: true}), do: "and fell on"
  defp ending(%{active: true}), do: "and was last seen on"
  defp ending(_missing), do: "and has not been seen since"

  defp medal_title(1), do: "First in the Halls"
  defp medal_title(2), do: "Second in the Halls"
  defp medal_title(3), do: "Third in the Halls"

  defp race_emoji(catalog, race_id) do
    case Enum.find(catalog.races, &(&1.id == race_id)) do
      nil -> "❓"
      race -> race.emoji
    end
  end

  attr :id, :string, required: true
  attr :at, :any, required: true

  @doc false
  # The text is UTC and correct without JS; the hook rewrites it to wherever the reader is.
  def stamp(assigns) do
    ~H"""
    <time id={@id} phx-hook="LocalTime" datetime={DateTime.to_iso8601(@at)}>{short_date(@at)}</time>
    """
  end

  defp short_date(at) do
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
