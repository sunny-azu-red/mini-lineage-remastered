defmodule MiniLineageWeb.Screens do
  @moduledoc """
  Which screen is drawn, and the screens themselves: character creation, the town a character
  stands in and its Gatekeeper, the character's own page, the Chronicles of Ancestry and the error
  page. `raw/1` renders flashes and lore, which the server
  composes from its own tables and never from anything a player typed.
  """
  use MiniLineageWeb, :html

  import MiniLineageWeb.Controls

  alias MiniLineage.Game.{Format, Math}
  alias MiniLineageWeb.Paths
  alias MiniLineageWeb.Screens.Halls

  @titles %{
    "start" => "A New Bloodline Rises",
    "gatekeeper" => "Gatekeeper",
    "character" => "Character",
    "races" => "Chronicles of Ancestry",
    "highscores" => "Monument of Heroes",
    "inventory" => "Inventory",
    "trader" => "Trader",
    "trainer" => "Trainer",
    "error" => "Error"
  }

  @doc "What the panel is headed: the town a run stands in, the screen's name elsewhere."
  def title("town", %{started: true, town: town}), do: town.name
  def title("hunt", %{started: true, ground: %{} = ground}), do: ground.name
  def title(screen, _view), do: Map.get(@titles, screen, "Mini Lineage")

  @doc "A place's emoji, drawn in the band beside its name; a screen that is not a place has none."
  def icon("town", %{started: true, town: town}), do: town.emoji
  def icon("start", _view), do: "🐣"
  def icon("gatekeeper", _view), do: "🌀"
  def icon("hunt", _view), do: "⚔️"
  def icon("inventory", _view), do: "🎒"
  def icon("trader", _view), do: "🛒"
  def icon("trainer", _view), do: "📖"
  def icon("highscores", _view), do: "🏛️"
  def icon(_screen, _view), do: nil

  def page_title(screen, view), do: "Mini Lineage - #{title(screen, view)}"

  @doc """
  The panels a screen is drawn on, top to bottom. The Chronicles give each lineage one of its own
  and the character page each section.
  """
  def panels("races", _view, catalog),
    do:
      for(
        race <- catalog.races,
        do: %{title: race.label, icon: race.emoji, race: race}
      )

  def panels("character", view, _catalog),
    do: [
      %{
        title: "#{view.name} of #{view.ancestry} Ancestry",
        icon: view.race_emoji,
        section: :lineage
      },
      %{title: "Buffs & Debuffs", icon: "✨", section: :effects, body_class: "rows"},
      %{title: "Combat Stats", icon: "⚖️", section: :stats},
      %{title: "Skills", icon: "📖", section: :skills, body_class: "rows"}
    ]

  def panels(screen, view, _catalog),
    do: [%{title: title(screen, view), icon: icon(screen, view)}]

  attr :screen, :string, required: true
  # Which of `panels/3` is being drawn.
  attr :panel, :map, required: true
  attr :view, :map, required: true
  attr :catalog, :map, required: true
  attr :detail, :string, default: nil
  attr :picked, :string, default: nil
  attr :debug, :boolean, default: false
  # Debug builds only: the name game start is already filled in with.
  attr :dev_name, :string, default: nil
  # The Halls: every board, the lineage filtered to, and the reader's own run.
  attr :boards, :map, default: %{}
  attr :lineage, :string, default: nil
  attr :character_id, :string, default: nil

  # Another tab can reset the character under the town; draw nothing until `pin_screen/2` moves on.
  def screen(%{view: %{started: false}, screen: screen} = assigns)
      when screen in ~w(town gatekeeper hunt trader trainer character inventory),
      do: ~H||

  def screen(%{screen: "start"} = assigns), do: start_screen(assigns)
  def screen(%{screen: "town"} = assigns), do: town(assigns)
  def screen(%{screen: "gatekeeper"} = assigns), do: gatekeeper(assigns)
  def screen(%{screen: "hunt"} = assigns), do: hunt(assigns)
  def screen(%{screen: "trader"} = assigns), do: trader(assigns)
  def screen(%{screen: "trainer"} = assigns), do: trainer(assigns)
  def screen(%{screen: "inventory"} = assigns), do: inventory(assigns)
  def screen(%{screen: "character"} = assigns), do: character(assigns)
  def screen(%{screen: "races"} = assigns), do: races(assigns)
  def screen(%{screen: "highscores"} = assigns), do: Halls.screen(assigns)
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
    <p>
      Will you forge a fresh path, or honour the names carved on the <.link patch={
        Paths.for_screen("highscores")
      }>Monument of Heroes</.link>? The
      <.link patch={Paths.for_screen("races")}>Chronicles of Ancestry</.link>
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
          <option :for={{path, label} <- paths()} value={path}>{label}</option>
        </select>
        <.button type="submit">🚩 Start</.button>
      </div>
    </form>
    """
  end

  # Somewhere to stand, and the way out of it: the systems that fill a town come later. The band
  # names it, so the body opens on the description rather than the name a second time.
  defp town(assigns) do
    ~H"""
    <p>{@view.town.description}</p>
    <%!-- No placeholder: there is no "nowhere" to go, so the first destination is preselected. --%>
    <.select_action
      id="travel-form"
      event="navigate"
      name="place"
      picked={@picked}
      options={town_places(@view)}
      default_label="🧭 Travel"
      active_label="🧭 Travel"
      default_variant={:primary}
    />
    """
  end

  # The places in a town: its Gatekeeper, and the ground outside it if it has one (rules §17).
  defp town_places(view) do
    [%{value: "gatekeeper", label: "🌀 Gatekeeper"}] ++
      if(view.stock != [], do: [%{value: "trader", label: "🛒 Trader"}], else: []) ++
      if(view.lessons != [], do: [%{value: "trainer", label: "📖 Trainer"}], else: []) ++
      if view.ground, do: [%{value: "hunt", label: "⚔️ #{view.ground.name}"}], else: []
  end

  # Rules §20: the ground, the skill the character fights with, and the one click that fights.
  defp hunt(assigns) do
    ~H"""
    <p id="hunt-intro" phx-no-format>
      Monsters roam the {@view.ground.name} outside {@view.town.emoji} {@view.town.name}, the young ones near the village and the strong ones further out. You go out to meet whatever comes nearest your strength, and fight it with your bare hands and your <span class={skill_class(@view.skill)}>{@view.skill.name}</span> until one of you falls.
    </p>
    <div class="action-links">
      <.button id="hunt-button" phx-click="hunt">⚔️ Hunt</.button>
    </div>
    """
  end

  @kinds [weapon: "Weapons", shield: "Shields", armour: "Armour", jewellery: "Jewellery"]

  # Rules §24: what the village sells, by kind, and what it would pay for what is carried.
  defp trader(assigns) do
    stock = Enum.group_by(assigns.view.stock, &kind_of(&1.slot))
    sellable = Enum.filter(assigns.view.items, &(!&1.equipped and &1.buyback > 0))
    assigns = assign(assigns, stock: stock, sellable: sellable, kinds: @kinds)

    ~H"""
    <p>
      The traders of {@view.town.emoji} {@view.town.name} sell what every village sells, at the price
      the lord's tax puts on it, and buy back what they sell for half of what they ask.
    </p>
    <%= for {kind, label} <- @kinds, @stock[kind] do %>
      <h3>{label}</h3>
      <.data_table id={"stock-#{kind}"}>
        <:col class="name">Item</:col>
        <:col class="name">What it is</:col>
        <:col>Adena</:col>
        <:col></:col>
        <tbody>
          <tr :for={item <- @stock[kind]} id={"stock-#{slug(item.name)}"}>
            <td class="name">{item.name}</td>
            <td class="name muted">{item.about}</td>
            <td class="adena">🪙 {Format.number(item.price)}</td>
            <td>
              <.button size={:sm} phx-click="buy" phx-value-item={item.name}>Buy</.button>
            </td>
          </tr>
        </tbody>
      </.data_table>
    <% end %>
    <h3>Sell</h3>
    <p :if={@sellable == []} id="nothing-to-sell">
      You carry nothing the traders would buy: they take nothing worn, and nothing from a starting kit.
    </p>
    <.data_table :if={@sellable != []} id="sellable">
      <:col class="name">Item</:col>
      <:col>Pays</:col>
      <:col></:col>
      <tbody>
        <tr :for={item <- @sellable} id={"sell-#{item.id}"}>
          <td class="name">{item.name}</td>
          <td class="adena">🪙 {Format.number(item.buyback)}</td>
          <td>
            <.button size={:sm} variant={:secondary} phx-click="sell" phx-value-id={item.id}>
              Sell
            </.button>
          </td>
        </tr>
      </tbody>
    </.data_table>
    """
  end

  # Rules §25: what the village's trainer teaches this set, and what the character can learn now.
  defp trainer(assigns) do
    ~H"""
    <p id="trainer-intro" phx-no-format>
      The trainers of {@view.town.emoji} {@view.town.name} teach their own, a level at a time, for the skill points you earn on the hunt. You have <span class="sp"><.figure key="trainer-sp" value={@view.sp} /> SP</span>.
    </p>
    <.data_table id="lessons">
      <:col class="name">Skill</:col>
      <:col class="num">Level</:col>
      <:col class="num">From level</:col>
      <:col>SP</:col>
      <:col></:col>
      <tbody>
        <tr
          :for={lesson <- @view.lessons}
          id={"lesson-#{slug(lesson.skill)}-#{lesson.level}"}
          data-status={lesson.status}
        >
          <td class="name">{lesson.skill}</td>
          <td class="num">{lesson.level}</td>
          <td class="num">{lesson.learn_at}</td>
          <td class="sp">{Format.number(lesson.sp)}</td>
          <td>
            <.button
              :if={lesson.status == :ready}
              size={:sm}
              phx-click="learn"
              phx-value-skill={lesson.skill}
              phx-value-level={lesson.level}
            >
              Learn
            </.button>
            <span :if={lesson.status == :known} class="muted">Known</span>
          </td>
        </tr>
      </tbody>
    </.data_table>
    """
  end

  # Rules §23: what is worn, by slot, and what is only carried.
  defp inventory(assigns) do
    {worn, carried} = Enum.split_with(assigns.view.items, & &1.equipped)

    assigns =
      assign(assigns, worn: worn, carried: carried, capacity: MiniLineage.Game.Rules.capacity())

    ~H"""
    <p id="inventory-count">
      You carry {length(@view.items)} of the {@capacity} things you can.
    </p>
    <h3>Worn</h3>
    <.data_table id="worn">
      <:col>Slot</:col>
      <:col class="name">Item</:col>
      <:col class="name">What it is</:col>
      <:col></:col>
      <tbody>
        <tr :for={item <- @worn} id={"item-#{item.id}"} data-worn="true">
          <td>{slot_label(item.slot)}</td>
          <td class="name">{item.name}</td>
          <td class="name muted">{item.about}</td>
          <td>
            <.button size={:sm} variant={:secondary} phx-click="unequip" phx-value-id={item.id}>
              Take off
            </.button>
          </td>
        </tr>
      </tbody>
    </.data_table>
    <h3>Carried</h3>
    <p :if={@carried == []} id="nothing-carried">You carry nothing you are not wearing.</p>
    <.data_table :if={@carried != []} id="carried">
      <:col class="name">Item</:col>
      <:col class="name">What it is</:col>
      <:col></:col>
      <tbody>
        <tr :for={item <- @carried} id={"item-#{item.id}"} data-worn="false">
          <td class="name">{item.name}</td>
          <td class="name muted">{item.about}</td>
          <td>
            <.button size={:sm} phx-click="equip" phx-value-id={item.id}>Put on</.button>
          </td>
        </tr>
      </tbody>
    </.data_table>
    """
  end

  defp kind_of(slot) when slot in [:weapon, :shield], do: slot
  defp kind_of(slot) when slot in [:necklace, :earring, :ring], do: :jewellery
  defp kind_of(_slot), do: :armour

  defp slot_label(slot), do: slot |> Atom.to_string() |> String.capitalize()

  defp slug(name), do: MiniLineage.Game.Format.slugify(name)

  defp skill_class(%{kind: kind}) when kind in [:physical, :blow], do: "attack"
  defp skill_class(_skill), do: "magic"

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
            label: "Pick #{route.emoji} #{route.name}",
            disabled?: !route.open?
          }
        end)
      }
      default_label="Return"
      active_label="🌀 Teleport"
    />
    """
  end

  # Only ever the reader's own, so it speaks to them. A chance moves only with DEX or WIT, so it is
  # not counted. Each clause stays on one line: a newline at a tag renders as a space. A panel with
  # figures has a hook of its own to count them; the sidebar's are its own.
  defp character(%{panel: %{section: :lineage}} = assigns) do
    assigns =
      assign(assigns,
        stats: assigns.view.stats,
        article: article(assigns.view.class_name),
        xp_needed: assigns.view.xp_required - assigns.view.xp_current
      )

    ~H"""
    <div id="character-lineage" phx-hook="AnimatedValues">
      <p id="character-class" phx-no-format>
        You are {@article} {@view.class_name} of <.attribute name="Strength" key="str" value={@stats.str} />, <.attribute name="Constitution" key="con" value={@stats.con} />, <.attribute name="Dexterity" key="dex" value={@stats.dex} />, <.attribute name="Intelligence" key="int" value={@stats.int} />, <.attribute name="Wit" key="wit" value={@stats.wit} /> and <.attribute name="Mental Strength" key="men" value={@stats.men} />. {@view.perk}
      </p>
      <p id="character-vitality" phx-no-format>
        You are at <span class="level">Level <.figure key="char-level" value={@view.level} /></span> with a total of <span class="xp"><.figure key="char-xp" value={@view.experience} /> XP</span><%= if @view.is_max_level do %>, standing unchallenged at the zenith of martial prowess<% else %>, requiring another <span class="xp"><.figure key="char-xp-needed" value={@xp_needed} /> XP</span> to reach <span class="level">Level <.figure key="char-next-level" value={@view.level + 1} /></span><% end %>, and your vitality sustains you at <span class="hp"><.figure key="char-hp" value={@view.health} /> HP</span> of <span class="hp"><.figure key="char-max-hp" value={@view.max_health} /> Max HP</span> and <span class="mp"><.figure key="char-mp" value={@view.mp} /> MP</span> of <span class="mp"><.figure key="char-max-mp" value={@view.max_mp} /> Max MP</span>, mending <span class="regen"><.figure key="char-hp-regen" value={Math.js_round(@stats.hp_regen)} /> HP</span> and <span class="regen"><.figure key="char-mp-regen" value={Math.js_round(@stats.mp_regen)} /> MP</span> every three seconds at rest, while your purse holds <span class="adena">🪙 <.figure key="char-adena" value={@view.adena} /> Adena</span> for the journey ahead.
      </p>
    </div>
    """
  end

  defp character(%{panel: %{section: :effects}} = assigns) do
    ~H"""
    <%!-- One row each, as the sidebar's; the sentence is one <p>, or the row would lay its pieces
          out as columns. --%>
    <div :for={effect <- @view.effects} id={"effect-#{effect.id}"} class="stat-row">
      <p phx-no-format>
        <span class={effect.type}>{effect.emoji} {effect.label}</span> <span class="muted">&bull;</span> {effect.about}<%= for {change, index} <- Enum.with_index(effect.changes) do %>{if index == 0, do: " ", else: " and "}<span class={stat_class(change.stat)}>{change.text}</span><% end %>{if effect.changes != [], do: "."}
      </p>
    </div>
    """
  end

  # Blows, then spells; Accuracy and Evasion decide only whether a blow lands (rules §13).
  defp character(%{panel: %{section: :stats}} = assigns) do
    stats = assigns.view.stats

    assigns =
      assign(assigns,
        stats: stats,
        critical: Float.round(stats.critical / 1, 1),
        magic_critical: Float.round(stats.magic_critical / 1, 1)
      )

    ~H"""
    <div id="character-stats" phx-hook="AnimatedValues">
      <p phx-no-format>
        You strike with <span class="attack"><.figure key="char-p-atk" value={Math.js_round(@stats.p_atk)} /> P. Atk.</span> at <span class="speed"><.figure key="char-atk-spd" value={Math.js_round(@stats.atk_spd)} /> Atk. Spd.</span> and {article(@critical)} <span id="character-critical" class="crit">{@critical}% Critical</span>, find the mark with <span class="accuracy"><.figure key="char-accuracy" value={Math.js_round(@stats.accuracy)} /> Accuracy</span>, and turn blows aside with <span class="defense"><.figure key="char-p-def" value={Math.js_round(@stats.p_def)} /> P. Def.</span> or slip them with <span class="evasion"><.figure key="char-evasion" value={Math.js_round(@stats.evasion)} /> Evasion</span>.
      </p>
      <p phx-no-format>
        You cast with <span class="magic"><.figure key="char-m-atk" value={Math.js_round(@stats.m_atk)} /> M. Atk.</span> at <span class="speed"><.figure key="char-cast-spd" value={Math.js_round(@stats.cast_spd)} /> Cast. Spd.</span> and {article(@magic_critical)} <span id="character-magic-critical" class="crit">{@magic_critical}% M. Critical</span>, and turn spells aside with <span class="defense"><.figure key="char-m-def" value={Math.js_round(@stats.m_def)} /> M. Def.</span>
      </p>
    </div>
    """
  end

  # Rules §25: what the character knows, its first skill's numbers at the level it knows it.
  defp character(%{panel: %{section: :skills}} = assigns) do
    ~H"""
    <div :for={{name, level} <- @view.skills} id={"skill-#{slug(name)}"} class="stat-row">
      <p phx-no-format>
        <span class="buff">{name}</span> <span class="muted">&bull;</span> level <span class="level">{level}</span>{skill_line(name, level)}
      </p>
    </div>
    <p>
      SP buys more from your village's trainer, and you hold <span class="sp">{Format.number(@view.sp)} SP</span>.
    </p>
    """
  end

  defp skill_line(name, level) do
    if Map.has_key?(MiniLineage.Game.Rules.skills(), name) do
      skill = MiniLineage.Game.Rules.skill(name, level)
      ", power #{skill.power} for #{skill.mp} MP."
    else
      "."
    end
  end

  # What an effect changes wears the colour of the stat it changes.
  defp stat_class(:accuracy), do: "accuracy"
  defp stat_class(stat) when stat in [:hp_regen, :mp_regen], do: "regen"

  # "an Elven Fighter", "a Dark Mystic", "a 4.6% Critical", "an 8.4% Critical", "an 11.0% Critical".
  defp article(word) when is_float(word), do: article(Float.to_string(word))

  defp article(word) do
    whole = word |> String.split(".") |> hd()
    if String.first(word) in ~w(A E I O U 8) or whole in ~w(11 18), do: "an", else: "a"
  end

  attr :name, :string, required: true
  attr :key, :string, required: true
  attr :value, :integer, required: true

  defp attribute(assigns) do
    ~H"""
    <span class="attribute" phx-no-format><.figure key={"char-#{@key}"} value={@value} /> {@name}</span>
    """
  end

  # The two paths, as game start offers them and the Chronicles name them.
  defp paths, do: [fighter: "⚔️ Fighter", mystic: "🔮 Mystic"]

  defp attributes,
    do: [
      str: "Strength",
      con: "Constitution",
      dex: "Dexterity",
      int: "Intelligence",
      wit: "Wit",
      men: "Mental Strength"
    ]

  # One lineage, in a panel of its own.
  defp races(%{panel: %{race: race}} = assigns) do
    assigns = assign(assigns, race: race)

    ~H"""
    <p>{raw(@race.backstory)}</p>
    <p id={"lineage-#{@race.slug}"}>
      {@race.perk} They start in {@race.town.emoji} {@race.town.name}.
    </p>
    <%!-- The panel names the race, so a row names only the path. --%>
    <.data_table id={"#{@race.slug}-classes"}>
      <:col class="name">Class</:col>
      <:col :for={{attr, name} <- attributes()} class="num" title={name}>
        {String.upcase(to_string(attr))}
      </:col>
      <:col class="num" title="Health Points">HP</:col>
      <:col class="num" title="Mana Points">MP</:col>
      <tbody>
        <tr :for={class <- @race.classes} id={"class-#{@race.slug}-#{class.path}"}>
          <td class="name">{paths()[class.path]}</td>
          <td :for={{attr, _} <- attributes()} class="num attribute">{class.attributes[attr]}</td>
          <td class="num hp">{class.max_hp}</td>
          <td class="num mp">{class.max_mp}</td>
        </tr>
      </tbody>
    </.data_table>
    """
  end
end
