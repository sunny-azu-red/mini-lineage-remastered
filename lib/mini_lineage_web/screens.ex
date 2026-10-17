defmodule MiniLineageWeb.Screens do
  @moduledoc """
  Which screen is drawn, and the screens themselves: character creation, the town a character
  stands in and its Gatekeeper, the character's own page, the Chronicles of Ancestry and the error
  page. `raw/1` renders flashes and lore, which the server
  composes from its own tables and never from anything a player typed.
  """
  use MiniLineageWeb, :html

  import MiniLineageWeb.Controls

  alias MiniLineage.Game.{Constants, Format, Hunt, Math, Narrative, Player, Rules}
  alias MiniLineageWeb.Paths
  alias MiniLineageWeb.Screens.Halls

  @titles %{
    "start" => "A New Bloodline Rises",
    "gatekeeper" => "Gatekeeper",
    "character" => "Character",
    "races" => "Chronicles of Ancestry",
    "highscores" => "Monument of Heroes",
    "inventory" => "Inventory",
    "trader" => "Traders",
    "trader-weapon" => "Weapon Trader",
    "trader-armour" => "Armour Trader",
    "trader-magic" => "Magic Trader",
    "trader-sell" => "Sell",
    "error" => "Error"
  }

  @doc "What the panel is headed: the town a run stands in, the screen's name elsewhere."
  def title("town", %{started: true, town: town}), do: town.name
  def title("hunt", %{started: true, ground: %{} = ground}), do: ground.name
  def title("guild", %{started: true, guild: guild}), do: guild.name
  def title(screen, _view), do: Map.get(@titles, screen, "Mini Lineage")

  @doc "A place's emoji, drawn in the band beside its name; a screen that is not a place has none."
  def icon("town", %{started: true, town: town}), do: town.emoji
  def icon("start", _view), do: "🐣"
  def icon("gatekeeper", _view), do: "🌀"
  def icon("hunt", _view), do: "⚔️"
  def icon("inventory", _view), do: "🎒"
  def icon("trader", _view), do: "🛒"
  def icon("trader-weapon", _view), do: "⚔️"
  def icon("trader-armour", _view), do: "🛡️"
  def icon("trader-magic", _view), do: "⚗️"
  def icon("trader-sell", _view), do: "💰"
  def icon("guild", _view), do: "📖"
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
      %{title: "Learned Skills", icon: "🎓", section: :skills, body_class: "rows"},
      %{title: "Battle Orders", icon: "📜", section: :orders}
    ]

  # Rules §25: what the guild teaches, and beside it what the character already knows, if anything.
  def panels("guild", view, _catalog),
    do:
      [%{title: title("guild", view), icon: icon("guild", view)}] ++
        if(view.skills == [],
          do: [],
          else: [%{title: "Learned Skills", icon: "🎓", section: :skills, body_class: "rows"}]
        )

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
  # Each sortable table's `{key, dir}`, by its id.
  attr :sorts, :map, default: %{}
  # Rules §20: the last fight on this ground, its log and what it came to.
  attr :fight, :map, default: nil
  # The inventory: the place it closes onto.
  attr :back, :any, default: nil

  # Another tab can reset the character under the town; draw nothing until `pin_screen/2` moves on.
  def screen(%{view: %{started: false}, screen: screen} = assigns)
      when screen in ~w(town gatekeeper hunt trader guild character inventory) or
             binary_part(screen, 0, min(byte_size(screen), 7)) == "trader-",
      do: ~H||

  def screen(%{screen: "start"} = assigns), do: start_screen(assigns)
  def screen(%{screen: "town"} = assigns), do: town(assigns)
  def screen(%{screen: "gatekeeper"} = assigns), do: gatekeeper(assigns)
  def screen(%{screen: "hunt"} = assigns), do: hunt(assigns)
  def screen(%{screen: "trader"} = assigns), do: trader(assigns)
  def screen(%{screen: "trader-" <> _} = assigns), do: trader_page(assigns)
  def screen(%{screen: "guild", panel: %{section: :skills}} = assigns), do: character(assigns)
  def screen(%{screen: "guild"} = assigns), do: guild(assigns)
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
          maxlength={Constants.character().name_max_length}
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
      if(view.stock != [], do: [%{value: "trader", label: "🛒 Traders"}], else: []) ++
      if(view.lessons != [], do: [%{value: "guild", label: "📖 #{view.guild.name}"}], else: []) ++
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
        Retreat to {@view.town.name}
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

  # Rules §24: each trader's page, whose line opens it and the slots it sells. The jeweller and the
  # grocer keep the Magic Trader together, as the Newbie Guide's shop of that name.
  @trader_parts [
    {"trader-weapon", :weapon, [:weapon]},
    {"trader-armour", :armour, [:shield, :chest, :legs]},
    {"trader-magic", :magic, [:necklace, :potion]}
  ]

  defp sellers(traders), do: [traders.weapon, traders.armour, traders.jewellery, traders.grocer]

  # Rules §26: how many potions one purchase may take.
  @potion_lots [1, 10]

  # The inventory's Slot column sorts in the order a character is dressed, not the alphabet's.
  @slot_order ~w(weapon shield necklace chest legs potion)a
  @class_keys ~w(class str con dex int wit men hp mp)

  # Rules §24: the village's four traders by name, on three pages, and selling, which any of them
  # does.
  defp trader(assigns) do
    parts =
      for {page, _, slots} <- @trader_parts,
          Enum.any?(assigns.view.stock, &(&1.slot in slots)),
          do: %{value: page, label: "#{icon(page, assigns.view)} #{Map.fetch!(@titles, page)}"}

    assigns = assign(assigns, parts: parts ++ [%{value: "trader-sell", label: "💰 Sell"}])

    ~H"""
    <p id="trader-intro" phx-no-format>
      {@view.traders.weapon} sells weapons, {@view.traders.armour} armour and shields, and {@view.traders.jewellery} and {@view.traders.grocer} jewellery and potions here in {@view.town.emoji} {@view.town.name}, and any of them buys back what they sell for half of what they ask.
    </p>
    <.select_action
      id="trader-form"
      event="navigate"
      name="place"
      picked={@picked}
      placeholder={"🚪 #{@view.town.name}"}
      options={@parts}
      default_label="Return"
      active_label="🛒 Browse"
    />
    """
  end

  defp trader_page(%{screen: "trader-sell"} = assigns) do
    sort = sort_of(assigns.sorts, "sellable")

    assigns =
      assign(assigns,
        sort: sort,
        sellable:
          assigns.view.items
          |> Enum.filter(&(!&1.equipped and &1.buyback > 0))
          |> sort_rows(sort, &item_key/2)
      )

    ~H"""
    <p id="sell-intro" phx-no-format>
      {Format.list(sellers(@view.traders), "and")} each buy back what they sell for half of what they ask.
    </p>
    <p :if={@sellable == []} id="nothing-to-sell">
      You carry nothing the traders would buy: they take nothing equipped, and nothing from a starting kit.
    </p>
    <.data_table :if={@sellable != []} id="sellable" sort={@sort}>
      <:col class="name" sort="name">Item</:col>
      <:col sort="buyback">Pays</:col>
      <tbody>
        <tr :for={item <- @sellable} id={"sell-#{item.id}"}>
          <td class="name">
            {item_label(item)} <span class="delimiter">&bull;</span>
            <span class="muted">{item.about}</span>
          </td>
          <td class="adena">🪙 {Format.number(item.buyback)}</td>
        </tr>
      </tbody>
    </.data_table>
    <.select_action
      id="sell-form"
      event="sell"
      name="item"
      picked={@picked}
      placeholder="🚪 Traders"
      options={Enum.map(@sellable, &%{value: &1.id, label: item_label(&1)})}
      default_label="Return"
      active_label="💰 Sell"
    />
    """
  end

  defp trader_page(assigns) do
    {_, role, slots} = List.keyfind(@trader_parts, assigns.screen, 0)

    # Shelves in the order the page's part lists them, in one table so the columns line up; a sort
    # reorders each shelf's rows and never mixes two shelves.
    sort = sort_of(assigns.sorts, "stock")

    shelves =
      assigns.view.stock
      |> Enum.filter(&(&1.slot in slots))
      |> Enum.sort_by(fn item -> Enum.find_index(slots, &(&1 == item.slot)) end)
      |> Enum.chunk_by(&shelf/1)
      |> Enum.map(fn [first | _] = items ->
        %{name: shelf(first), items: sort_rows(items, sort, &item_key/2)}
      end)

    assigns =
      assign(assigns,
        sort: sort,
        shelves: shelves,
        line: Constants.trader_line(assigns.view.town.slug, role)
      )

    ~H"""
    <p id="trader-intro">{@line}</p>
    <.data_table id="stock" sort={@sort}>
      <:col class="name" sort="name">Item</:col>
      <:col sort="price">Adena</:col>
      <tbody :for={shelf <- @shelves} id={"shelf-#{slug(shelf.name)}"}>
        <%!-- A page of one shelf (a Dark Fighter's daggers, a Mystic's staves) needs no heading. --%>
        <tr :if={length(@shelves) > 1} class="shelf">
          <th colspan="2" scope="rowgroup">{shelf.name}</th>
        </tr>
        <tr :for={item <- shelf.items} id={"stock-#{slug(item.name)}"}>
          <td class="name">
            {item_label(item)} <span class="delimiter">&bull;</span>
            <span class="muted">{item.about}</span>
          </td>
          <td class="adena">🪙 {Format.number(item.price)}</td>
        </tr>
      </tbody>
    </.data_table>
    <.select_action
      id="buy-form"
      event="buy"
      name="item"
      picked={@picked}
      placeholder="🚪 Traders"
      options={buy_options(@shelves)}
      default_label="Return"
      active_label="🪙 Buy"
    />
    """
  end

  # Rules §25: every line the set has still to learn, muted unless it can be learned next, on an
  # Active and a Passive shelf as a trader's goods are; what it knows is the panel beside it. SP is
  # paid like Adena, so a line short of it is still offered.
  defp guild(assigns) do
    sort = sort_of(assigns.sorts, "lessons")

    # Each skill's next line only: the ones after it are learned in order, so listing them is clutter.
    shelves =
      assigns.view.lessons
      |> Enum.reject(&(&1.status == :known))
      |> Enum.uniq_by(& &1.skill)
      |> Enum.group_by(&lesson_shelf/1)
      |> Enum.sort_by(fn {name, _} -> name end)
      |> Enum.map(fn {name, lessons} ->
        %{name: name, lessons: sort_rows(lessons, sort, &lesson_key/2)}
      end)

    assigns =
      assign(assigns,
        sort: sort,
        shelves: shelves,
        ready:
          for(
            shelf <- shelves,
            lesson <- shelf.lessons,
            lesson.status == :ready,
            do: Map.put(lesson, :group, if(length(shelves) > 1, do: shelf.name))
          )
      )

    ~H"""
    <p id="guild-intro" phx-hook="AnimatedValues" phx-no-format>
      {Format.list(@view.guild.trainers, "and")} teach their own here in {@view.town.emoji} {@view.town.name}, a level at a time, for the skill points you earn on the hunt. You have <span class="sp"><.figure key="guild-sp" value={@view.sp} /> SP</span>.
    </p>
    <.data_table id="lessons" sort={@sort}>
      <:col class="name" sort="skill">Skill</:col>
      <:col class="num" title="Level Required" sort="learn_at">Level Req</:col>
      <:col title="Skill Points" sort="sp">SP</:col>
      <tbody :for={shelf <- @shelves} id={"shelf-#{slug(shelf.name)}"}>
        <tr :if={length(@shelves) > 1} class="shelf">
          <th colspan="3" scope="rowgroup">{shelf.name}</th>
        </tr>
        <tr
          :for={lesson <- shelf.lessons}
          id={"lesson-#{slug(lesson.skill)}-#{lesson.level}"}
          data-status={lesson.status}
          {if lesson.status == :ready, do: [], else: [class: "locked"]}
        >
          <td class="name">
            {skill_icon(lesson.skill)} {lesson.skill} {lesson.level}
            <%= if Rules.weapon_skill?(lesson.skill) do %>
              <span class="delimiter">&bull;</span>
              <span class="muted">Needs {Narrative.weapon_for(lesson.skill)}</span>
            <% end %>
          </td>
          <td class="num level">{lesson.learn_at}</td>
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
            label: "#{skill_icon(&1.skill)} #{&1.skill} #{&1.level}",
            group: &1.group
          }
        )
      }
      default_label="Return"
      active_label="📖 Learn"
    />
    """
  end

  # "Active" sorts before "Passive", which is the order the shelves stand in.
  defp lesson_shelf(lesson),
    do: if(Rules.skill(lesson.skill).kind == :passive, do: "Passive", else: "Active")

  defp lesson_key(lesson, "skill"), do: {lesson.skill, lesson.level}
  defp lesson_key(lesson, "learn_at"), do: lesson.learn_at
  defp lesson_key(lesson, "sp"), do: lesson.sp

  @doc """
  The keys a table may be sorted on, checked before a sort is stored, the sort it opens on, and
  whether the reader's sort outlives a reload; a remembered table also sets `remember` on its
  `<.data_table>`.
  """
  def sortable("stock"), do: table(~w(name price), {"price", :asc})
  def sortable("sellable"), do: table(~w(name buyback), {"buyback", :desc})
  def sortable("items"), do: table(~w(name slot), {"slot", :asc})
  def sortable("routes-table"), do: table(~w(name fee), {"fee", :asc})
  def sortable("lessons"), do: table(~w(skill learn_at sp), {"learn_at", :asc})
  def sortable("halls-table"), do: table(~w(name level total_xp adena), {"total_xp", :desc})

  def sortable(table) do
    if String.ends_with?(table, "-classes"),
      do: table(@class_keys, {"class", :asc}),
      else: %{keys: [], default: nil, remember: false}
  end

  defp table(keys, default), do: %{keys: keys, default: default, remember: false}

  @doc "The sort a table is drawn in: the reader's, else the one it opens on."
  def sort_of(sorts, table), do: sorts[table] || sortable(table).default

  # Rules §23: everything carried in one list, what is equipped highlighted, and one choice of what
  # to do with which, grouped by what it does; destroying anything is the red button.
  defp inventory(assigns) do
    sort = sort_of(assigns.sorts, "items")
    items = sort_rows(assigns.view.items, sort, &item_key/2)

    assigns =
      assign(assigns,
        sort: sort,
        items: items,
        capacity: Rules.capacity(),
        choices: inventory_choices(items),
        back_title: back_title(assigns.back, assigns.view)
      )

    ~H"""
    <p id="inventory-count">You carry {length(@view.items)} of the {@capacity} things you can.</p>
    <.data_table id="items" sort={@sort}>
      <:col class="name" sort="name">Item</:col>
      <:col sort="slot">Slot</:col>
      <tbody>
        <tr
          :for={item <- @items}
          id={"item-#{item.id}"}
          data-equipped={to_string(item.equipped)}
          {if item.equipped, do: [class: "owned"], else: []}
        >
          <td class="name">
            {item_label(item)} <span class="delimiter">&bull;</span>
            <span class="muted">{item.about}</span>
          </td>
          <td>{item.slot |> Atom.to_string() |> String.capitalize()}</td>
        </tr>
      </tbody>
    </.data_table>
    <.select_action
      id="inventory-form"
      event="inventory"
      name="item"
      picked={@picks["item"]}
      placeholder={"🚪 #{@back_title}"}
      options={@choices}
      default_label="Return"
    />
    """
  end

  # Each verb's items under its own heading, so one list holds them all; the value is "<verb>:<id>".
  @inventory_verbs [
    {"equip", "Equip", "⬆️ Equip", :primary},
    {"unequip", "Unequip", "⬇️ Unequip", :primary},
    {"drink", "Drink", "🧪 Drink", :primary},
    {"destroy", "Destroy", "🗑️ Destroy", :danger}
  ]

  defp inventory_choices(items) do
    for {verb, group, action, variant} <- @inventory_verbs,
        item <- items,
        inventory_verb?(verb, item),
        do: %{
          value: "#{verb}:#{item.id}",
          label: item_label(item),
          group: group,
          action: action,
          variant: variant
        }
  end

  defp inventory_verb?("equip", item), do: !item.potion? and !item.equipped
  defp inventory_verb?("unequip", item), do: item.equipped
  defp inventory_verb?("drink", item), do: item.potion?
  defp inventory_verb?("destroy", item), do: !item.equipped

  defp back_title({screen, _town}, view), do: title(screen, view)
  defp back_title(nil, view), do: view.town.name

  # Gear is bought one at a time, a potion (§26) by the lot, onto its stack. Each shelf is a group,
  # in the order its table shows, as long as there are two to tell apart.
  defp buy_options(shelves) do
    for shelf <- shelves,
        # A generator, not `group = …`: in `for` that is a filter, and a nil group drops the shelf.
        group <- [if(length(shelves) > 1, do: shelf.name)],
        item <- shelf.items,
        n <- if(item.slot == :potion, do: @potion_lots, else: [nil]),
        do:
          if(n,
            do: %{value: "#{item.name}|#{n}", label: "#{item_label(item)} ×#{n}", group: group},
            else: %{value: item.name, label: item_label(item), group: group}
          )
  end

  # Which shelf of a trader's an item is on, its heading in the table and in the dropdown.
  defp shelf(%{slot: :weapon, type: type}),
    do:
      Map.fetch!(
        %{
          "sword" => "Swords",
          "dagger" => "Daggers",
          "bow" => "Bows",
          "fists" => "Fists",
          "staff" => "Staves"
        },
        type
      )

  defp shelf(%{slot: :shield}), do: "Shields"

  # A chest and legs share a shelf by what they are, so a top sits beside the bottom it pairs with.
  defp shelf(%{slot: slot, type: "light"}) when slot in [:chest, :legs], do: "Light Armour"
  defp shelf(%{slot: slot, type: "magic"}) when slot in [:chest, :legs], do: "Robes"
  defp shelf(%{slot: :necklace}), do: "Necklaces"
  defp shelf(%{slot: :potion}), do: "Potions"

  # A name sorts on the item's name, never the emoji before it; a slot in the game's own order.
  defp item_key(item, "name"), do: item.name
  defp item_key(item, "price"), do: item.price
  defp item_key(item, "buyback"), do: item.buyback

  defp item_key(item, "slot"),
    do: {Enum.find_index(@slot_order, &(&1 == item.slot)), !item.equipped}

  defp slug(name), do: MiniLineage.Game.Format.slugify(name)

  defp route_key(route, "name"), do: route.name
  defp route_key(route, "fee"), do: route.fee

  # Rules §14: every route out of this town and its fee, then the choice of one.
  defp gatekeeper(assigns) do
    sort = sort_of(assigns.sorts, "routes-table")

    assigns =
      assign(assigns, sort: sort, routes: sort_rows(assigns.view.routes, sort, &route_key/2))

    ~H"""
    <p id="gatekeeper-intro" phx-no-format>
      {@view.town.gatekeeper} the Gatekeeper can send you on from {@view.town.emoji} {@view.town.name} in the blink of an eye, to any town the routes from here reach, for a fee.
    </p>
    <.data_table id="routes-table" sort={@sort}>
      <:col class="name" sort="name">Destination</:col>
      <:col sort="fee">Adena</:col>
      <tbody>
        <tr :for={route <- @routes} id={"route-#{route.slug}"}>
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
        Enum.map(@routes, fn route ->
          %{
            value: route.slug,
            label: "#{route.emoji} #{route.name}",
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
    <%!-- Each row counts its own time down: they sit straight in the panel body, so no wrapper can. --%>
    <div
      :for={effect <- @view.effects}
      id={"effect-#{effect.id}"}
      class="stat-row"
      phx-hook={effect_hook(effect)}
    >
      <p phx-no-format>
        <span class={effect.type}>{effect.emoji} {effect.label}</span> <span class="delimiter">&bull;</span> {effect.about}<%= if effect.rates != [] do %> <%= for {rate, index} <- Enum.with_index(effect.rates) do %>{if index > 0, do: " and "}<span class={if rate.value < 0, do: "mp", else: "regen"}>{if rate.value < 0, do: "-", else: "+"}<.figure key={"effect-#{effect.id}-#{rate_unit(rate.stat) |> String.downcase()}"} value={abs(rate.value)} /> {rate_unit(rate.stat)}</span><% end %> every three seconds.<% end %><%= for {change, index} <- Enum.with_index(effect.changes) do %>{if index == 0, do: " ", else: " and "}<span class={stat_class(change.stat)}>{change.text}</span><% end %><%= cond do %><% effect.changes != [] and effect.remaining_ms -> %> for another <.timer ms={effect.remaining_ms} key={effect.timer_key} />.<% effect.changes != [] -> %>.<% effect.remaining_ms -> %> {lapse(effect.type)} <.timer ms={effect.remaining_ms} key={effect.timer_key} />.<% true -> %><% end %>
      </p>
    </div>
    """
  end

  # What the character deals, then what it withstands and how fast it closes in (rules §20);
  # Accuracy, Evasion and a shield's block decide only whether a blow lands and how hard (§13, §23).
  defp character(%{panel: %{section: :stats}} = assigns) do
    stats = assigns.view.stats

    assigns =
      assign(assigns,
        stats: stats,
        critical: Float.round(stats.critical / 1, 1),
        magic_critical: Float.round(stats.magic_critical / 1, 1),
        block:
          stats.shield &&
            Float.round(Hunt.block_chance(stats.shield.shield_rate, stats.dex) / 1, 1)
      )

    ~H"""
    <div id="character-stats" phx-hook="AnimatedValues">
      <p phx-no-format>
        You strike with <span class="attack"><.figure key="char-p-atk" value={Math.js_round(@stats.p_atk)} /> P. Atk.</span> at <span class="speed"><.figure key="char-atk-spd" value={Math.js_round(@stats.atk_spd)} /> Atk. Spd.</span> and {article(@critical)} <span id="character-critical" class="crit"><.figure key="char-critical" value={round(@stats.critical * 10)} format={:tenths} />% Critical</span>, find the mark with <span class="accuracy"><.figure key="char-accuracy" value={Math.js_round(@stats.accuracy)} /> Accuracy</span>, and cast with <span class="magic"><.figure key="char-m-atk" value={Math.js_round(@stats.m_atk)} /> M. Atk.</span> at <span class="speed"><.figure key="char-cast-spd" value={Math.js_round(@stats.cast_spd)} /> Cast. Spd.</span> and {article(@magic_critical)} <span id="character-magic-critical" class="crit"><.figure key="char-magic-critical" value={round(@stats.magic_critical * 10)} format={:tenths} />% M. Critical</span>.
      </p>
      <p phx-no-format>
        You turn blows aside with <span class="defense"><.figure key="char-p-def" value={Math.js_round(@stats.p_def)} /> P. Def.</span><span :if={@block}> and {article(@block)} <span id="character-block" class="defense"><.figure key="char-block" value={round(@block * 10)} format={:tenths} />% Block</span>,</span> or slip them with <span class="evasion"><.figure key="char-evasion" value={Math.js_round(@stats.evasion)} /> Evasion</span>, turn spells aside with <span class="defense"><.figure key="char-m-def" value={Math.js_round(@stats.m_def)} /> M. Def.</span>, and run at <span class="speed"><.figure key="char-run-spd" value={Math.js_round(@stats.run_spd)} /> Run Spd.</span>
      </p>
    </div>
    """
  end

  # Rules §19 and §25: what the character knows, each skill's numbers at the level it knows it, each
  # figure in the colour of what it is. §23 and §20: one the weapon in hand cannot use, or the orders
  # leave unused, is muted, and says why.
  defp character(%{panel: %{section: :skills}} = assigns) do
    ~H"""
    <div :if={@view.skills == []} id="no-skills" class="stat-row">
      <p class="muted">
        You have learned no skill yet, visit the trainers of your home village.
      </p>
    </div>
    <div
      :for={{name, level} <- @view.skills}
      id={"skill-#{slug(name)}"}
      phx-hook="AnimatedValues"
      class={[
        "stat-row",
        (!Rules.skill_weapon?(name, @view.stats.weapon) or name in @view.unused) && "locked"
      ]}
    >
      <p phx-no-format>
        {skill_icon(name)} <span class="skill">{name} {level}</span> <span class="delimiter">&bull;</span> <.skill_effect skill={Rules.skill(name, level, @view.path)} stats={@view.stats} /><%= if !Rules.skill_weapon?(name, @view.stats.weapon) do %> Needs {Narrative.weapon_for(name)} equipped.<% end %><%= if name in @view.unused do %> Left unused, by your orders.<% end %>
      </p>
    </div>
    """
  end

  # Rules §20 and §26: how the character fights on its own, as the player orders it: when it drinks
  # a potion, once it knows a heal when it heals before the pull and in the fight, and which of its
  # skills it leaves unused.
  defp character(%{panel: %{section: :orders}} = assigns) do
    orders =
      [{"potion", "🧪 Potions", :potion_at}] ++
        if(assigns.view.heals?,
          do: [
            {"pull", "💚 Heal before the pull", :heal_pull_at},
            {"fight", "💚 Heal in the fight", :heal_fight_at}
          ],
          else: []
        )

    shares =
      for {kind, label, key} <- orders,
          share <- Player.potion_shares(),
          do: %{
            value: "#{kind}:#{share}",
            label: "#{label}: #{if share == 0, do: "never", else: "below #{share}% HP"}",
            disabled?: share == Map.fetch!(assigns.view, key)
          }

    switches =
      for name <- assigns.view.switchable,
          use? <- [true, false],
          do: %{
            value: "use:#{use?}:#{name}",
            label: "#{skill_icon(name)} #{name}: #{if use?, do: "use it", else: "leave unused"}",
            disabled?: use? != name in assigns.view.unused
          }

    assigns = assign(assigns, options: shares ++ switches)

    ~H"""
    <p id="potion-share" phx-no-format>
      <%= if @view.potion_at == 0 do %>You drink no potions in a fight.<% else %>In a fight you drink a potion whenever your HP falls below <span class="hp">{@view.potion_at}%</span>.<% end %>
    </p>
    <p :if={@view.heals?} id="heal-pull-share" phx-no-format>
      <%= if @view.heal_pull_at == 0 do %>You never heal before a pull.<% else %>Before a pull you heal while your HP is below <span class="hp">{@view.heal_pull_at}%</span>.<% end %>
    </p>
    <p :if={@view.heals?} id="heal-fight-share" phx-no-format>
      <%= if @view.heal_fight_at == 0 do %>You never heal in a fight.<% else %>In a fight you heal below <span class="hp">{@view.heal_fight_at}%</span> of your HP while your spells rest.<% end %>
    </p>
    <p :if={@view.switchable != []} id="unused-skills" phx-no-format>
      <%= if @view.unused == [] do %>You use every skill you know.<% else %>You leave {Format.list(Enum.map(@view.unused, &"#{skill_icon(&1)} #{&1}"), "and")} unused.<% end %>
    </p>
    <.select_action
      id="orders-form"
      event="order"
      name="order"
      picked={@picks["order"]}
      placeholder="📜 Change an order…"
      options={@options}
      default_label="Choose"
      active_label="📜 Order"
      data-no-autofocus
    />
    """
  end

  # A row counts what moves in it: its time left, or what a tick of rest mends. None has both.
  defp effect_hook(%{remaining_ms: ms}) when is_integer(ms), do: "EffectTimers"
  defp effect_hook(%{rates: [_ | _]}), do: "AnimatedValues"
  defp effect_hook(_effect), do: nil

  defp rate_unit(:hp_regen), do: "HP"
  defp rate_unit(:mp_regen), do: "MP"

  # What a timed effect with no stat to change says: a buff is something you still have, a debuff
  # something you are still under, and In Combat, the one timed aura, the wait before rest.
  defp lapse(:buff), do: "It holds for another"
  defp lapse(:debuff), do: "It lifts in"
  defp lapse(:aura), do: "You rest again in"

  attr :ms, :integer, required: true
  attr :key, :string, required: true

  defp timer(assigns),
    do:
      ~H|<span class="timer" data-timer="long" data-remaining-ms={@ms} data-timer-key={@key}>{Format.remaining(
  @ms
)}</span>|

  # One each, since a set learns two of a kind (the Orc Fighter, two physical skills).
  @skill_icons %{
    "Power Strike" => "💥",
    "Power Shot" => "🏹",
    "Mortal Blow" => "🎯",
    "Iron Punch" => "👊",
    "Wind Strike" => "🌪️",
    "Ice Bolt" => "❄️",
    "Vampiric Touch" => "🦇",
    "Chill Flame" => "🔥",
    "Drain Health" => "🩸",
    "Life Drain" => "👻",
    "Self Heal" => "💚",
    "Heal" => "💖",
    "Elemental Heal" => "💧",
    "Curse: Poison" => "☠️",
    "Wind Shackle" => "⛓️",
    "Soul Cry" => "📢",
    "Armor Mastery" => "🪖",
    "Robe Mastery" => "👘",
    "Weapon Mastery" => "🤺",
    "Anti Magic" => "🧿"
  }

  @doc "A skill's own emoji, or for one that raises an aura that aura's, as Buffs shows it."
  def skill_icon(name) do
    if Rules.skill(name).kind in [:aura, :rest],
      do: Constants.skill_aura(name).emoji,
      else: Map.fetch!(@skill_icons, name)
  end

  attr :skill, :map, required: true
  attr :stats, :map, required: true

  # Rules §19, worked for this character: what a skill does in the numbers the fight uses, then how
  # long it takes, so nobody works out √M.Atk or × 333 ÷ Atk. Spd. by hand.
  defp skill_effect(assigns) do
    %{skill: skill, stats: stats} = assigns
    tenths = &round(&1 / 100)

    assigns =
      assign(assigns,
        key: "skill-#{slug(skill.name)}",
        reuse:
          skill.kind not in [:aura, :toggle, :rest, :passive] &&
            tenths.(Hunt.reuse_ms(skill, stats)),
        cast: skill[:cast] && tenths.(Hunt.cast_ms(skill, stats))
      )

    ~H"""
    <.skill_does skill={@skill} stats={@stats} key={@key} />
    <%= if @cast do %>
      Cast in
      <span class="speed"><.figure key={"#{@key}-cast"} value={@cast} format={:tenths} /> seconds</span>
      <%= if @reuse do %>
        , ready again every
        <span class="speed"><.figure key={"#{@key}-reuse"} value={@reuse} format={:tenths} /> seconds</span>
      <% end %>.
    <% else %>
      <%= if @reuse do %>
        Ready again every <span class="speed"><.figure key={"#{@key}-reuse"} value={@reuse} format={:tenths} /> seconds</span>.
      <% end %>
    <% end %>
    """
  end

  attr :skill, :map, required: true
  attr :stats, :map, required: true
  attr :key, :string, required: true

  defp skill_does(%{skill: %{kind: :physical}} = assigns),
    do:
      ~H|<span class="attack">Power {@skill.power}</span>, never missing, for <span class="mp">{@skill.mp} MP</span>.|

  defp skill_does(%{skill: %{kind: :blow}} = assigns),
    do:
      ~H|<span class="attack">Power {@skill.power}</span>, landing <span class="accuracy"><.figure key={"#{@key}-lands"} value={round(Hunt.blow_chance(@stats.dex) * 10)} format={:tenths} />% of the time</span>, for <span class="mp">{@skill.mp} MP</span>.|

  defp skill_does(%{skill: %{kind: :magic, slow: true}} = assigns) do
    assigns = assign(assigns, slow: Hunt.slow())

    ~H|<span class="magic">Power {@skill.power}</span>, slowing the foe's swing and run by
<span class="speed">{percent_off(@slow.times)}</span>
for {duration(@slow.ms)}, for <span class="mp">{@skill.mp} MP</span>.|
  end

  defp skill_does(%{skill: %{kind: :magic}} = assigns),
    do:
      ~H|<span class="magic">Power {@skill.power}</span> for <span class="mp">{@skill.mp} MP</span>.|

  defp skill_does(%{skill: %{kind: :drain}} = assigns),
    do:
      ~H|<span class="magic">Power {@skill.power}</span>, mending <span class="regen">{round(@skill.absorb * 100)}% of the HP it takes</span>, for <span class="mp">{@skill.mp} MP</span>.|

  defp skill_does(%{skill: %{kind: :burn}} = assigns) do
    assigns = assign(assigns, lasts: Hunt.burn_ms())

    ~H|Burns <span class="magic">{@skill.power} HP a second</span>
for {duration(@lasts)}, <span class="magic">{div(@skill.power * @lasts, 1000)} HP</span>
in all, for <span class="mp">{@skill.mp} MP</span>.|
  end

  defp skill_does(%{skill: %{kind: :heal}} = assigns),
    do: ~H|Mends
<span class="regen"><.figure
  key={"#{@key}-mends"}
  value={Hunt.heal_amount(@skill.power, @stats.m_atk)}
/> HP</span>
for <span class="mp">{@skill.mp} MP</span>.|

  defp skill_does(%{skill: %{kind: :aura}} = assigns),
    do:
      ~H|<span class={stat_class(@skill.stat)}>+{round((@skill.times - 1) * 100)}% {stat_name(@skill.stat)}</span>
for {duration(@skill.lasts)}, for <span class="mp">{@skill.mp} MP</span>.|

  defp skill_does(%{skill: %{kind: :poison}} = assigns),
    do:
      ~H|Takes <span class="debuff">{@skill.power} HP</span>
every {duration(@skill.every)} for {duration(@skill.lasts)},
<span class="debuff">{div(@skill.power * @skill.lasts, @skill.every)} HP</span>
in all, landing <span class="accuracy">{@skill.land}% of the time</span>, for <span class="mp">{@skill.mp} MP</span>.|

  defp skill_does(%{skill: %{kind: :shackle}} = assigns),
    do:
      ~H|The foe swings <span class="speed">{percent_off(@skill.times)} slower</span>
for {duration(@skill.lasts)}, landing <span class="accuracy">{@skill.land}% of the time</span>, for <span class="mp">{@skill.mp} MP</span>.|

  defp skill_does(%{skill: %{kind: :toggle}} = assigns),
    do: ~H|<span class="attack">P.Atk +{@skill.power}</span>
for <span class="mp">{@skill.mp} MP</span>, then <span class="mp">{@skill.drain} MP</span>
every {duration(@skill.every)}.|

  defp skill_does(%{skill: %{kind: :rest}} = assigns),
    do: ~H|<span class="regen">+{@skill.power} HP</span>
a tick of rest for <span class="mp">{@skill.mp} MP</span>.|

  # Rules §19: what a mastery adds, as the rules write it ("+13.4 P.Def in a robe", "+8.5% P.Atk and
  # +2 P.Atk"), each bonus naming its stat: a stat's bonuses joined by "and", the stats by commas.
  defp skill_does(%{skill: %{kind: :passive}} = assigns) do
    bonuses = assigns.skill.bonuses
    key = &{&1.stat, &1[:worn]}

    groups =
      for group <- bonuses |> Enum.map(key) |> Enum.uniq(),
          do: Enum.filter(bonuses, &(key.(&1) == group))

    assigns = assign(assigns, groups: groups)

    ~H"""
    <span phx-no-format><%= for {[first | _] = group, index} <- Enum.with_index(@groups) do %>{if index > 0, do: ", "}<%= for {bonus, at} <- Enum.with_index(group) do %>{if at > 0, do: " and "}<span class={stat_class(bonus.stat)}>{bonus(bonus)} {stat_name(bonus.stat)}</span><% end %>{worn(first[:worn])}<% end %>.</span>
    """
  end

  # "+2", or "+8.5%" for a × 1.085.
  defp bonus(%{times: times}) do
    share = Float.round((times - 1) * 100, 1)
    "+#{if share == trunc(share), do: trunc(share), else: share}%"
  end

  defp bonus(%{add: add}), do: "+#{add}"

  defp worn(nil), do: ""
  defp worn("light"), do: " in light armour"
  defp worn("magic"), do: " in a robe"

  # "30%" for a × 0.7.
  defp percent_off(times), do: "#{round((1 - times) * 100)}%"

  defp duration(ms) when ms >= 60_000 and rem(ms, 60_000) == 0,
    do: if(ms == 60_000, do: "a minute", else: "#{div(ms, 60_000)} minutes")

  defp duration(ms), do: "#{div(ms, 1000)} seconds"

  defp stat_name(:p_def), do: "P.Def"
  defp stat_name(:p_atk), do: "P.Atk"
  defp stat_name(:m_atk), do: "M.Atk"
  defp stat_name(:m_def), do: "M.Def"
  defp stat_name(:evasion), do: "Evasion"

  # What an effect changes wears the colour of the stat it changes.
  defp stat_class(:accuracy), do: "accuracy"
  defp stat_class(stat) when stat in [:hp_regen, :mp_regen], do: "regen"
  defp stat_class(stat) when stat in [:p_def, :m_def], do: "defense"
  defp stat_class(:m_atk), do: "magic"
  defp stat_class(:p_atk), do: "attack"
  defp stat_class(:evasion), do: "evasion"

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

  defp class_key(class, "class"), do: class.path
  defp class_key(class, "hp"), do: class.max_hp
  defp class_key(class, "mp"), do: class.max_mp

  defp class_key(class, attr),
    do:
      class.attributes[Enum.find_value(attributes(), fn {a, _} -> to_string(a) == attr && a end)]

  # One lineage, in a panel of its own.
  defp races(%{panel: %{race: race}} = assigns) do
    id = "#{race.slug}-classes"
    sort = sort_of(assigns.sorts, id)

    assigns =
      assign(assigns,
        race: race,
        id: id,
        sort: sort,
        classes: sort_rows(race.classes, sort, &class_key/2)
      )

    ~H"""
    <p>{raw(@race.backstory)}</p>
    <p id={"lineage-#{@race.slug}"}>
      {@race.perk} They start in {@race.town.emoji} {@race.town.name}.
    </p>
    <%!-- The panel names the race, so a row names only the path. --%>
    <.data_table id={@id} sort={@sort}>
      <:col class="name" sort="class">Class</:col>
      <:col :for={{attr, name} <- attributes()} class="num" title={name} sort={to_string(attr)}>
        {String.upcase(to_string(attr))}
      </:col>
      <:col class="num" title="Health Points" sort="hp">HP</:col>
      <:col class="num" title="Mana Points" sort="mp">MP</:col>
      <tbody>
        <tr :for={class <- @classes} id={"class-#{@race.slug}-#{class.path}"}>
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
