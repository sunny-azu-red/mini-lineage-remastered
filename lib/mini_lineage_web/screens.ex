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
    "trader-swords" => "Trader: Swords",
    "trader-blunts" => "Trader: Blunt Weapons",
    "trader-daggers" => "Trader: Daggers",
    "trader-bows" => "Trader: Bows",
    "trader-polearms" => "Trader: Polearms",
    "trader-fists" => "Trader: Fists",
    "trader-staves" => "Trader: Staves and Books",
    "trader-shields" => "Trader: Shields",
    "trader-armour" => "Trader: Armour",
    "trader-jewellery" => "Trader: Jewellery",
    "trader-potions" => "Trader: Potions",
    "trader-sell" => "Trader: Sell",
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
  def icon("trader" <> _, _view), do: "🛒"
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

  # Rules §23: what is equipped and carried, and beside it the stats it makes, which count as gear moves.
  def panels("inventory", _view, _catalog),
    do: [
      %{title: "Inventory", icon: "🎒", section: :inventory},
      %{title: "Combat Stats", icon: "⚖️", section: :stats}
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
  # What each dropdown on the screen has picked, by its field.
  attr :picks, :map, default: %{}
  # Rules §20: the last fight on this ground, its log and what it came to.
  attr :fight, :map, default: nil

  # Another tab can reset the character under the town; draw nothing until `pin_screen/2` moves on.
  def screen(%{view: %{started: false}, screen: screen} = assigns)
      when screen in ~w(town gatekeeper hunt trader trainer character inventory) or
             binary_part(screen, 0, min(byte_size(screen), 7)) == "trader-",
      do: ~H||

  def screen(%{screen: "start"} = assigns), do: start_screen(assigns)
  def screen(%{screen: "town"} = assigns), do: town(assigns)
  def screen(%{screen: "gatekeeper"} = assigns), do: gatekeeper(assigns)
  def screen(%{screen: "hunt"} = assigns), do: hunt(assigns)
  def screen(%{screen: "trader"} = assigns), do: trader(assigns)
  def screen(%{screen: "trader-" <> _} = assigns), do: trader_page(assigns)
  def screen(%{screen: "trainer"} = assigns), do: trainer(assigns)
  def screen(%{screen: "inventory", panel: %{section: :stats}} = assigns), do: character(assigns)
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

  # Rules §20: the ground, how the character fights, and the one click that fights again.
  defp hunt(assigns) do
    ~H"""
    <p id="hunt-intro" phx-no-format>
      Monsters roam the {@view.ground.name} outside {@view.town.emoji} {@view.town.name}, the young ones near the village and the strong ones further out. You go out to meet whatever comes nearest your strength, and fight it with what is in your hands and every skill you know until one of you falls.
    </p>
    <div class="action-links">
      <.button id="hunt-button" phx-click="hunt">⚔️ Look for more action</.button>
      <.button id="retreat-button" variant={:secondary} phx-click="retreat">
        🚪 Retreat to {@view.town.name}
      </.button>
    </div>
    <div :if={@fight} id="fight">
      <h3>The last fight</h3>
      <ol id="fight-log" class="fight-log">
        <li :for={line <- @fight.log}>{raw(line)}</li>
      </ol>
      <p id="fight-outcome">{raw(@fight.text)}</p>
    </div>
    """
  end

  # Rules §24: what the trader's pages hold, in the order the menu offers them, each with its label.
  @trader_parts [
    {"trader-swords", "🗡️ Swords", "swords", {:types, ["sword", "two-handed sword"]}},
    {"trader-blunts", "🔨 Blunt weapons", "blunt weapons", {:types, ["blunt"]}},
    {"trader-daggers", "🔪 Daggers", "daggers", {:types, ["dagger"]}},
    {"trader-bows", "🏹 Bows", "bows", {:types, ["bow"]}},
    {"trader-polearms", "🔱 Polearms", "polearms", {:types, ["pole"]}},
    {"trader-fists", "🥊 Fists", "fist weapons", {:types, ["fists"]}},
    {"trader-staves", "🪄 Staves and books", "staves and books",
     {:types, ["two-handed blunt", "staff"]}},
    {"trader-shields", "🛡️ Shields", "shields", {:slots, [:shield]}},
    {"trader-armour", "👕 Armour", "armour", {:slots, [:chest, :legs]}},
    {"trader-jewellery", "📿 Jewellery", "necklaces", {:slots, [:necklace]}},
    {"trader-potions", "🧪 Potions", "potions", {:slots, [:potion]}}
  ]

  # Rules §26: how many potions one purchase may take.
  @potion_lots [1, 10, 50, 100]

  defp in_part?(item, {:types, types}), do: item.slot == :weapon and item.type in types
  defp in_part?(item, {:slots, slots}), do: item.slot in slots

  # Rules §24: the trader's menu, each part of what it sells, and selling, a page of its own.
  defp trader(assigns) do
    parts =
      for {page, label, _, part} <- @trader_parts,
          Enum.any?(assigns.view.stock, &in_part?(&1, part)),
          do: %{value: page, label: label}

    assigns = assign(assigns, parts: parts ++ [%{value: "trader-sell", label: "💰 Sell"}])

    ~H"""
    <p>
      The traders of {@view.town.emoji} {@view.town.name} sell what every village sells, and buy back
      what they sell for half of what they ask. What would you like to see?
    </p>
    <.select_action
      id="trader-form"
      event="navigate"
      name="place"
      picked={@picked}
      placeholder={"🚪 #{@view.town.name}"}
      options={@parts}
      default_label="Return"
      active_label="Browse"
    />
    """
  end

  # Rules §24: one part of the trader's stock, in a table, and the choice of what to buy.
  defp trader_page(%{screen: "trader-sell"} = assigns) do
    assigns =
      assign(assigns,
        sellable: Enum.filter(assigns.view.items, &(!&1.equipped and &1.buyback > 0))
      )

    ~H"""
    <p :if={@sellable == []} id="nothing-to-sell">
      You carry nothing the traders would buy: they take nothing equipped, and nothing from a starting kit.
    </p>
    <.data_table :if={@sellable != []} id="sellable">
      <:col class="name">Item</:col>
      <:col class="name">Stats</:col>
      <:col>Pays</:col>
      <tbody>
        <tr :for={item <- @sellable} id={"sell-#{item.id}"}>
          <td class="name">{item.name}</td>
          <td class="name muted">{item.about}</td>
          <td class="adena">🪙 {Format.number(item.buyback)}</td>
        </tr>
      </tbody>
    </.data_table>
    <.select_action
      id="sell-form"
      event="sell"
      name="id"
      picked={@picked}
      placeholder="🛒 Back to the trader"
      options={
        Enum.map(
          @sellable,
          &%{value: &1.id, label: "Sell the #{&1.name} for #{Format.number(&1.buyback)}"}
        )
      }
      default_label="Return"
      active_label="💰 Sell"
    />
    """
  end

  defp trader_page(assigns) do
    {_, _, what, part} = List.keyfind(@trader_parts, assigns.screen, 0)

    assigns =
      assign(assigns, stock: Enum.filter(assigns.view.stock, &in_part?(&1, part)), what: what)

    ~H"""
    <p>The traders lay out their {@what}.</p>
    <.data_table id="stock">
      <:col class="name">Item</:col>
      <:col class="name">Stats</:col>
      <:col>Adena</:col>
      <tbody>
        <tr :for={item <- @stock} id={"stock-#{slug(item.name)}"}>
          <td class="name">{item.name}</td>
          <td class="name muted">{item.about}</td>
          <td class="adena">🪙 {Format.number(item.price)}</td>
        </tr>
      </tbody>
    </.data_table>
    <.select_action
      id="buy-form"
      event="buy"
      name="item"
      picked={@picked}
      placeholder="🛒 Back to the trader"
      options={buy_options(@stock)}
      default_label="Return"
      active_label="🪙 Buy"
    />
    """
  end

  # Rules §25: what the character knows, highlighted, and what it can learn now; nothing it cannot.
  defp trainer(assigns) do
    lessons = Enum.filter(assigns.view.lessons, &(&1.status in [:known, :ready]))

    assigns =
      assign(assigns, lessons: lessons, ready: Enum.filter(lessons, &(&1.status == :ready)))

    ~H"""
    <p id="trainer-intro" phx-no-format>
      The trainers of {@view.town.emoji} {@view.town.name} teach their own, a level at a time, for the skill points you earn on the hunt. You have <span class="sp"><.figure key="trainer-sp" value={@view.sp} /> SP</span>.
    </p>
    <.data_table id="lessons">
      <:col class="name">Skill</:col>
      <:col class="num">Level</:col>
      <:col class="num">From level</:col>
      <:col>SP</:col>
      <tbody>
        <tr
          :for={lesson <- @lessons}
          id={"lesson-#{slug(lesson.skill)}-#{lesson.level}"}
          data-status={lesson.status}
          {if lesson.status == :known, do: [class: "owned"], else: []}
        >
          <td class="name">{lesson.skill}</td>
          <td class="num">{lesson.level}</td>
          <td class="num">{lesson.learn_at}</td>
          <td class="sp">{Format.number(lesson.sp)}</td>
        </tr>
      </tbody>
    </.data_table>
    <p :if={@ready == []} id="nothing-to-learn" class="muted">
      There is nothing more for you to learn until you grow stronger.
    </p>
    <.select_action
      id="learn-form"
      event="learn"
      name="lesson"
      picked={@picked}
      placeholder={"🚪 #{@view.town.name}"}
      options={
        Enum.map(
          @ready,
          &%{
            value: "#{&1.skill}|#{&1.level}",
            label: "📖 #{&1.skill} #{&1.level} for #{Format.number(&1.sp)} SP"
          }
        )
      }
      default_label="Return"
      active_label="📖 Learn"
    />
    """
  end

  # Rules §23: everything carried in one list, what is equipped highlighted, then two choices: what to
  # put on or take off, and, apart and in red, what to destroy.
  defp inventory(assigns) do
    picked = Enum.find(assigns.view.items, &(&1.id == assigns.picks["id"]))

    wear_label =
      cond do
        picked && picked.potion? -> "🧪 Drink"
        picked && picked.equipped -> "Take off"
        true -> "Put on"
      end

    assigns =
      assign(assigns,
        capacity: MiniLineage.Game.Rules.capacity(),
        carried: Enum.reject(assigns.view.items, & &1.equipped),
        wear_label: wear_label,
        shares: MiniLineage.Game.Player.potion_shares()
      )

    ~H"""
    <p id="inventory-count">You carry {length(@view.items)} of the {@capacity} things you can.</p>
    <.data_table id="items">
      <:col class="name">Item</:col>
      <:col>Slot</:col>
      <:col class="name">Stats</:col>
      <tbody>
        <tr
          :for={item <- @view.items}
          id={"item-#{item.id}"}
          data-equipped={to_string(item.equipped)}
          {if item.equipped, do: [class: "owned"], else: []}
        >
          <td class="name">{item_emoji(item)} {item_name(item)}</td>
          <td>{item.slot |> Atom.to_string() |> String.capitalize()}</td>
          <td class="name muted">{item.about}</td>
        </tr>
      </tbody>
    </.data_table>
    <.select_action
      id="wear-form"
      event="wear"
      name="id"
      picked={@picks["id"]}
      placeholder={"🚪 #{@view.town.name}"}
      options={
        Enum.map(
          @view.items,
          &%{
            value: &1.id,
            label: "#{item_emoji(&1)} #{item_name(&1)}#{if &1.equipped, do: " (equipped)"}"
          }
        )
      }
      default_label="Return"
      active_label={@wear_label}
    />
    <.select_action
      :if={@carried != []}
      id="destroy-form"
      event="destroy"
      name="doomed"
      picked={@picks["doomed"]}
      placeholder="🗑️ Destroy something you carry…"
      options={Enum.map(@carried, &%{value: &1.id, label: "🗑️ #{item_name(&1)}"})}
      default_label="Destroy"
      active_label="🗑️ Destroy"
      active_variant={:danger}
      data-no-autofocus
    />
    <p id="potion-share" phx-no-format>
      <%= if @view.potion_at == 0 do %>You drink no potions in a fight.<% else %>In a fight you drink a potion whenever your HP falls below <span class="hp">{@view.potion_at}%</span>.<% end %>
    </p>
    <.select_action
      id="potion-form"
      event="potion_at"
      name="share"
      picked={@picks["share"]}
      placeholder="🧪 Drink potions in a fight…"
      options={
        for share <- @shares,
            do: %{
              value: to_string(share),
              label: if(share == 0, do: "🧪 Never", else: "🧪 Below #{share}% HP"),
              disabled?: share == @view.potion_at
            }
      }
      default_label="Choose"
      active_label="🧪 Choose"
      data-no-autofocus
    />
    """
  end

  # Rules §26: a stack names how many it holds.
  defp item_name(%{potion?: true} = item), do: "#{item.name} ×#{item.count}"
  defp item_name(item), do: item.name

  # Gear is bought one at a time, a potion (§26) by the lot, onto its stack.
  defp buy_options(stock) do
    Enum.flat_map(stock, fn
      %{slot: :potion} = item ->
        for n <- @potion_lots,
            do: %{
              value: "#{item.name}|#{n}",
              label: "Buy #{n} × #{item.name} for #{Format.number(item.price * n)}"
            }

      item ->
        [%{value: item.name, label: "Buy the #{item.name} for #{Format.number(item.price)}"}]
    end)
  end

  defp item_emoji(%{slot: :weapon, type: type}) do
    case type do
      "bow" -> "🏹"
      "fists" -> "🥊"
      "dagger" -> "🔪"
      "pole" -> "🔱"
      t when t in ["two-handed blunt", "staff"] -> "🪄"
      "blunt" -> "🔨"
      _ -> "🗡️"
    end
  end

  defp item_emoji(%{slot: :shield}), do: "🛡️"
  defp item_emoji(%{slot: :chest}), do: "👕"
  defp item_emoji(%{slot: :legs}), do: "👖"
  defp item_emoji(%{slot: :necklace}), do: "📿"
  defp item_emoji(%{slot: :potion}), do: "🧪"

  defp slug(name), do: MiniLineage.Game.Format.slugify(name)

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

  # Only ever the reader's own, so it speaks to them. Each clause stays on one line: a newline at a
  # tag renders as a space. A panel with figures has a hook of its own to count them; the sidebar's
  # are its own.
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
        You strike with <span class="attack"><.figure key="char-p-atk" value={Math.js_round(@stats.p_atk)} /> P. Atk.</span> at <span class="speed"><.figure key="char-atk-spd" value={Math.js_round(@stats.atk_spd)} /> Atk. Spd.</span> and {article(@critical)} <span id="character-critical" class="crit"><.figure key="char-critical" value={round(@stats.critical * 10)} format={:tenths} />% Critical</span>, find the mark with <span class="accuracy"><.figure key="char-accuracy" value={Math.js_round(@stats.accuracy)} /> Accuracy</span>, and turn blows aside with <span class="defense"><.figure key="char-p-def" value={Math.js_round(@stats.p_def)} /> P. Def.</span> or slip them with <span class="evasion"><.figure key="char-evasion" value={Math.js_round(@stats.evasion)} /> Evasion</span>.
      </p>
      <p phx-no-format>
        You cast with <span class="magic"><.figure key="char-m-atk" value={Math.js_round(@stats.m_atk)} /> M. Atk.</span> at <span class="speed"><.figure key="char-cast-spd" value={Math.js_round(@stats.cast_spd)} /> Cast. Spd.</span> and {article(@magic_critical)} <span id="character-magic-critical" class="crit"><.figure key="char-magic-critical" value={round(@stats.magic_critical * 10)} format={:tenths} />% M. Critical</span>, and turn spells aside with <span class="defense"><.figure key="char-m-def" value={Math.js_round(@stats.m_def)} /> M. Def.</span>
      </p>
    </div>
    """
  end

  # Rules §19 and §25: what the character knows, each skill's numbers at the level it knows it.
  defp character(%{panel: %{section: :skills}} = assigns) do
    ~H"""
    <div :for={{name, level} <- @view.skills} id={"skill-#{slug(name)}"} class="stat-row">
      <p phx-no-format>
        <span class="buff">{name}</span> <span class="muted">&bull;</span> level <span class="level">{level}</span>{skill_line(name, level)}
      </p>
    </div>
    """
  end

  defp skill_line(name, level), do: skill_effect(MiniLineage.Game.Rules.skill(name, level))

  defp skill_effect(%{kind: :heal} = s),
    do: ", mends #{s.power} HP and √M.Atk more for #{s.mp} MP."

  defp skill_effect(%{kind: :aura} = s),
    do: ", #{stat_name(s.stat)} ×#{s.times} for #{div(s.lasts, 60_000)} minutes, for #{s.mp} MP."

  defp skill_effect(%{kind: :poison} = s),
    do:
      ", #{s.power} HP every #{div(s.every, 1000)} seconds for #{div(s.lasts, 1000)} seconds, for #{s.mp} MP."

  defp skill_effect(%{kind: :shackle} = s),
    do: ", the foe swings ×#{s.times} for #{div(s.lasts, 1000)} seconds, for #{s.mp} MP."

  defp skill_effect(%{kind: :toggle} = s),
    do:
      ", P.Atk +#{s.power} for #{s.mp} MP, then #{s.drain} MP every #{div(s.every, 1000)} seconds."

  defp skill_effect(%{kind: :rest} = s), do: ", +#{s.power} HP a tick of rest for #{s.mp} MP."
  defp skill_effect(s), do: ", power #{s.power} for #{s.mp} MP."

  defp stat_name(:p_def), do: "P.Def"
  defp stat_name(:p_atk), do: "P.Atk"

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
