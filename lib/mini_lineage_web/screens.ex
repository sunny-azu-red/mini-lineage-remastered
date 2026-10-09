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

  @titles %{
    "start" => "A New Bloodline Rises",
    "gatekeeper" => "Gatekeeper",
    "character" => "Character",
    "races" => "Chronicles of Ancestry",
    "error" => "Error"
  }

  @doc "What the panel is headed: the town a run stands in, the screen's name elsewhere."
  def title("town", %{started: true, town: town}), do: town.name
  def title(screen, _view), do: Map.get(@titles, screen, "Mini Lineage")

  @doc "A place's emoji, drawn in the band beside its name; a screen that is not a place has none."
  def icon("town", %{started: true, town: town}), do: town.emoji
  def icon("start", _view), do: "🐣"
  def icon("gatekeeper", _view), do: "🌀"
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
      %{title: "Blessings & Afflictions", icon: "✨", section: :effects, body_class: "rows"},
      %{title: "Stats", icon: "📊", section: :stats}
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

  # Another tab can reset the character under the town; draw nothing until `pin_screen/2` moves on.
  def screen(%{view: %{started: false}, screen: screen} = assigns)
      when screen in ~w(town gatekeeper character),
      do: ~H||

  def screen(%{screen: "start"} = assigns), do: start_screen(assigns)
  def screen(%{screen: "town"} = assigns), do: town(assigns)
  def screen(%{screen: "gatekeeper"} = assigns), do: gatekeeper(assigns)
  def screen(%{screen: "character"} = assigns), do: character(assigns)
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
      assign(assigns, stats: assigns.view.stats, article: article(assigns.view.class_name))

    ~H"""
    <div id="character-lineage" phx-hook="AnimatedValues">
      <p id="character-class" phx-no-format>
        You are {@article} {@view.class_name} of <.attribute name="STR" key="str" value={@stats.str} />, <.attribute name="CON" key="con" value={@stats.con} />, <.attribute name="DEX" key="dex" value={@stats.dex} />, <.attribute name="INT" key="int" value={@stats.int} />, <.attribute name="WIT" key="wit" value={@stats.wit} /> and <.attribute name="MEN" key="men" value={@stats.men} />.
      </p>
      <p id="character-perk">{@view.perk}</p>
    </div>
    """
  end

  defp character(%{panel: %{section: :effects}} = assigns) do
    ~H"""
    <%!-- One row each, as the sidebar's; the sentence is one <p>, or the row would lay its pieces
          out as columns. --%>
    <div :for={effect <- @view.effects} id={"effect-#{effect.id}"} class="stat-row">
      <p>
        <span class={effect.type}>{effect.emoji} {effect.label}</span>
        <span class="muted">&bull;</span> {effect_text(effect)}
      </p>
    </div>
    """
  end

  defp character(%{panel: %{section: :stats}} = assigns) do
    assigns =
      assign(assigns,
        stats: assigns.view.stats,
        xp_needed: assigns.view.xp_required - assigns.view.xp_current
      )

    ~H"""
    <div id="character-stats" phx-hook="AnimatedValues">
      <p phx-no-format>
        You strike with <span class="attack"><.figure key="char-p-atk" value={Math.js_round(@stats.p_atk)} /> P. Atk.</span> and <span class="magic"><.figure key="char-m-atk" value={Math.js_round(@stats.m_atk)} /> M. Atk.</span>, turn blows aside with <span class="defense"><.figure key="char-p-def" value={Math.js_round(@stats.p_def)} /> P. Def.</span> and <span class="defense"><.figure key="char-m-def" value={Math.js_round(@stats.m_def)} /> M. Def.</span>, and find the mark with <span class="accuracy"><.figure key="char-accuracy" value={Math.js_round(@stats.accuracy)} /> Accuracy</span> while slipping blows with <span class="evasion"><.figure key="char-evasion" value={Math.js_round(@stats.evasion)} /> Evasion</span>.
      </p>
      <p phx-no-format>
        Your blows run at <span id="character-critical" class="crit">{Float.round(@stats.critical / 1, 1)}% Critical</span> and your spells at <span id="character-magic-critical" class="crit">{Float.round(@stats.magic_critical / 1, 1)}% M. Critical</span>, swinging at <span class="speed"><.figure key="char-atk-spd" value={Math.js_round(@stats.atk_spd)} /> Atk. Spd.</span> and casting at <span class="speed"><.figure key="char-cast-spd" value={Math.js_round(@stats.cast_spd)} /> Cast. Spd.</span> At rest you mend <span class="regen"><.figure key="char-hp-regen" value={Math.js_round(@stats.hp_regen)} /> HP</span> and <span class="regen"><.figure key="char-mp-regen" value={Math.js_round(@stats.mp_regen)} /> MP</span> every three seconds.
      </p>
      <p id="character-vitality" phx-no-format>
        You are at <span class="level">Level <.figure key="char-level" value={@view.level} /></span> with a total of <span class="xp"><.figure key="char-xp" value={@view.experience} /> XP</span><%= if @view.is_max_level do %>, standing unchallenged at the zenith of martial prowess<% else %>, requiring another <span class="xp"><.figure key="char-xp-needed" value={@xp_needed} /> XP</span> to reach <span class="level">Level <.figure key="char-next-level" value={@view.level + 1} /></span><% end %>, and your vitality sustains you at <span class="hp"><.figure key="char-hp" value={@view.health} /> HP</span> of <span class="hp"><.figure key="char-max-hp" value={@view.max_health} /> Max HP</span> and <span class="mp"><.figure key="char-mp" value={@view.mp} /> MP</span> of <span class="mp"><.figure key="char-max-mp" value={@view.max_mp} /> Max MP</span> while your purse holds <span class="adena">🪙 <.figure key="char-adena" value={@view.adena} /> Adena</span> for the journey ahead.
      </p>
    </div>
    """
  end

  # What it is, then what it changes as one sentence: "... ×1.5 HP regen and ×1.5 MP regen."
  defp effect_text(%{changes: []} = effect), do: effect.about
  defp effect_text(effect), do: "#{effect.about} #{Enum.join(effect.changes, " and ")}."

  # "an Elven Fighter", "a Dark Mystic".
  defp article(name), do: if(String.first(name) in ~w(A E I O U), do: "an", else: "a")

  attr :name, :string, required: true
  attr :key, :string, required: true
  attr :value, :integer, required: true

  defp attribute(assigns) do
    ~H"""
    <span class="attribute" phx-no-format>{@name} <.figure key={"char-#{@key}"} value={@value} /></span>
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
          <td :for={{attr, _} <- attributes()} class="num">{class.attributes[attr]}</td>
          <td class="num hp">{class.max_hp}</td>
          <td class="num mp">{class.max_mp}</td>
        </tr>
      </tbody>
    </.data_table>
    """
  end
end
