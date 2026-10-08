defmodule MiniLineageWeb.Screens.Record do
  @moduledoc """
  One run's whole story, at `/character/:id`. Public because it is on the board, so there is
  nothing here to gate.
  """
  use MiniLineageWeb, :html

  import MiniLineageWeb.Controls

  alias MiniLineageWeb.Controls

  alias MiniLineage.Game.{Format, Math, Narrative, Narratives}

  attr :view, :map, required: true
  attr :catalog, :map, required: true
  attr :entry, :map, default: nil
  attr :mine, :boolean, default: true

  @doc false
  # One record, whoever is reading it. `mine` switches the voice: yours speaks to you, anybody
  # else's speaks about them. The verbs never move — they/them takes the same forms as you.
  def record(assigns) do
    race = Enum.find(assigns.catalog.races, &(&1.id == assigns.view.race_id))
    opponent = Enum.find(assigns.catalog.races, &(&1.id == race.enemy_race_id))

    # Numbers named up here so each stat and its punctuation fit on one line: the formatter breaks
    # a long line at a tag, and a newline there renders as a space before the full stop.
    assigns =
      assign(assigns,
        race: race,
        opponent: opponent,
        dead: assigns.view.dead,
        # The set the narratives are filled from, so a sentence and the page cannot disagree.
        voice: Narratives.voice(assigns.mine),
        # Nothing walks with a run walked away from; decided here because only the row knows.
        effects: if(held?(assigns.entry), do: assigns.view.effects, else: []),
        # Only the tense moves between a run still going and one that is over.
        fought: if(assigns.view.dead, do: "fought", else: "have fought"),
        stats: assigns.view.stats,
        class_name: assigns.view.class_name
      )

    # The closing paragraph forks outright: its sentences change shape, not just their tense.
    ~H"""
    <%!-- One hook counts every [data-value] beneath it; only names and dates jump. --%>
    <div id="record-figures" phx-hook="AnimatedValues">
      <h2>{@race.emoji} {@view.name} of {@race.label} Ancestry</h2>
      <%!-- What the lineage gave this run, told to its reader; the lore is the Chronicles of
            Ancestry's to tell. --%>
      <p>{raw(voiced(@race.traits, @mine))}</p>

      <.blessings :if={@effects != []} effects={@effects} voice={@voice} />

      <h2>🎒 Inventory &amp; Stats</h2>
      <p phx-no-format>
        {@voice.they} {if @dead, do: "were wielding", else: "are wielding"} the {@view.weapon.emoji} <span class="item">{@view.weapon.name}</span><%= if (@view.weapon.crit || 0) > 0 do %> granting <span class="crit">+<.figure key="rec-weapon-crit" value={@view.weapon.crit} /> Critical</span><% end %>, and {if @dead, do: "wore", else: "wearing"} the {@view.armor.emoji} <span class="item">{@view.armor.name}</span><%= if (@view.armor.regen || 0) > 0 do %> granting <span class="regen">+<.figure key="rec-armor-regen" value={@view.armor.regen} /> HP Regeneration</span><% end %>.
      </p>
      <p phx-no-format>
        {@voice.they} {if @dead, do: "were", else: "are"} {article(@class_name)} {@class_name} of <.attribute name="STR" key="str" value={@stats.str} />, <.attribute name="CON" key="con" value={@stats.con} />, <.attribute name="DEX" key="dex" value={@stats.dex} />, <.attribute name="INT" key="int" value={@stats.int} />, <.attribute name="WIT" key="wit" value={@stats.wit} /> and <.attribute name="MEN" key="men" value={@stats.men} />.
      </p>
      <p phx-no-format>
        {@voice.they} {if @dead, do: "struck", else: "strike"} with <span class="attack"><.figure key="rec-p-atk" value={trunc(@stats.p_atk)} id="char-stat-p-atk" /> P. Atk.</span> and <span class="magic"><.figure key="rec-m-atk" value={trunc(@stats.m_atk)} id="char-stat-m-atk" /> M. Atk.</span>, {if @dead, do: "turned", else: "turn"} blows aside with <span class="defense"><.figure key="rec-p-def" value={trunc(@stats.p_def)} id="char-stat-p-def" /> P. Def.</span> and <span class="defense"><.figure key="rec-m-def" value={trunc(@stats.m_def)} id="char-stat-m-def" /> M. Def.</span>, and {if @dead, do: "found", else: "find"} the mark with <span class="accuracy"><.figure key="rec-accuracy" value={@stats.accuracy} id="char-stat-accuracy" /> Accuracy</span> while slipping blows with <span class="evasion"><.figure key="rec-evasion" value={@stats.evasion} id="char-stat-evasion" /> Evasion</span>.
      </p>
      <p phx-no-format>
        {@voice.whose} blows {if @dead, do: "ran", else: "run"} at <span class="crit"><.figure key="rec-crit" value={@stats.crit_rate} id="char-stat-crit" /> Critical</span> and {@voice.their} spells at <span class="crit"><.figure key="rec-m-crit" value={@stats.m_crit_rate} id="char-stat-m-crit" /> Magic Critical</span>, swinging at <span class="speed"><.figure key="rec-atk-spd" value={@stats.p_atk_spd} id="char-stat-atk-spd" /> Atk. Spd.</span> and casting at <span class="speed"><.figure key="rec-cast-spd" value={@stats.m_atk_spd} id="char-stat-cast-spd" /> Casting Spd.</span> At rest {@voice.them} {if @dead, do: "mended", else: "mend"} <span class="regen"><.figure key="rec-regen" value={Math.js_round(@stats.hp_regen)} id="char-stat-regen" /> HP</span> and <span class="mp"><.figure key="rec-mp-regen" value={Math.js_round(@stats.mp_regen)} id="char-stat-mp-regen" /> MP</span> every three seconds, while navigating the roads with a <span class="ambush"><.figure key="rec-ambush" value={@stats.ambush_risk} id="char-stat-ambush" />% Ambush Risk</span>.
      </p>

      <h2>{if @dead, do: "☠️ #{@voice.whose} Journey Has Ended", else: "🧭 The Journey So Far"}</h2>
      <p>
        <.road entry={@entry} dead={@view.dead} at={@entry && @entry.last_seen_at} voice={@voice} />
        {@voice.they} {@fought} through
        <Controls.counted
          key="rec-battles"
          class="battles"
          count={@view.counters.total_battles}
          singular="battle"
          plural="battles"
        />, slaying
        <Controls.counted
          key="rec-slain"
          class="kills"
          count={@view.counters.total_enemies_killed}
          singular={@opponent.label}
          plural={@opponent.plural}
          emoji={@opponent.emoji}
        />
        <%= if @view.counters.total_ambushes > 0 do %>
          and overcoming
          <Controls.counted
            key="rec-ambushes"
            count={@view.counters.total_ambushes}
            singular="cunning ambush"
            plural="cunning ambushes"
            class="ambush"
          />
        <% end %>
        along the way.
      </p>

      <%= if @dead do %>
        <p phx-no-format>
        {@voice.they} fell at <span class="level">Level <.figure key="rec-level" value={@view.level} /></span>
        with a total of <span class="xp"><.figure key="rec-xp" value={@view.experience} /> XP</span><%= if @view.is_max_level do %>, standing unchallenged at the zenith of martial prowess<% else %>, only <span class="xp"><.figure key="rec-xp-needed" value={@view.xp_needed} /> XP</span> short of <span class="level">Level <.figure key="rec-next-level" value={@view.level + 1} /></span><% end %>, and <%= if @view.adena > 0 do %>left <span class="adena">🪙 <.figure key="rec-adena" value={@view.adena} format={:adena} /> Adena</span> unspent<% else %>died with an empty purse<% end %>.
      </p>
      <% else %>
        <p id="char-vitality" phx-no-format>
        Experience wise, {@voice.them} are at <span class="level">Level <.figure key="rec-level" value={@view.level} /></span>
        with a total of <span class="xp"><.figure key="rec-xp" value={@view.experience} /> XP</span><%= if @view.is_max_level do %>, standing unchallenged at the zenith of martial prowess<% else %>, requiring another <span class="xp"><.figure key="rec-xp-needed" value={@view.xp_needed} /> XP</span> to reach <span class="level">Level <.figure key="rec-next-level" value={@view.level + 1} /></span><% end %>
        and {@voice.their} vitality currently sustains {@voice.object} at
        <span class="hp"><.figure key="char-hp" value={@view.health} id="char-hp" />
        / <.figure key="rec-max-hp" value={@view.max_health} id="char-max-hp" />
        HP</span> and <span class="mp"><.figure key="char-mp" value={@view.mp} id="char-mp" />
        / <.figure key="rec-max-mp" value={@view.max_mp} id="char-max-mp" />
        MP</span>
        while {@voice.their} purse holds <span class="adena">🪙 <.figure key="rec-adena" value={@view.adena} format={:adena} /> Adena</span>
        for the journey ahead.
      </p>
      <% end %>
    </div>
    """
  end

  # "an Elven Fighter", "a Dark Mystic".
  defp article(name), do: if(String.first(name) in ~w(A E I O U), do: "an", else: "a")

  attr :name, :string, required: true
  attr :key, :string, required: true
  attr :value, :integer, required: true

  defp attribute(assigns) do
    ~H"""
    <span class="attribute" phx-no-format>{@name} <.figure key={"rec-#{@key}"} value={@value} id={"char-stat-#{@key}"} /></span>
    """
  end

  defp held?(%{active: true}), do: true
  defp held?(_retired_or_missing), do: false

  attr :effects, :list, required: true
  attr :voice, :map, required: true

  @doc false
  # What is riding on a run, spelled out: the header's emoji alone a phone can neither hover nor
  # read. Drawn only when the list is not empty, since the heading belongs to the list.
  defp blessings(assigns) do
    ~H"""
    <h2>✨ Blessings &amp; Afflictions</h2>
    <%!-- One hook repaints every countdown on the same second; the server's expiry removes a line. --%>
    <div id="record-effects" phx-hook="EffectTimers">
      <p
        :for={effect <- @effects}
        data-effect-id={effect.id}
        data-remaining-ms={effect.remaining_ms}
      >
        <span class={effect.type}>{effect.emoji} {effect.label}</span>
        <span class="muted">&bull;</span> {raw(Narrative.build_effect(effect, @voice))}
        <%!-- Only the figure is dimmed, like a date: a whole clause in grey reads as an aside. --%>
        <span :if={effect.remaining_ms}>{lapse(effect.type)}
        <span class="timer" data-timer="long">{Format.remaining(effect.remaining_ms)}</span>.</span>
      </p>
    </div>
    """
  end

  # A buff is something you still have, a debuff something you are still under, and a lingering
  # aura something that is settling — three different things for a clock to be counting down to.
  defp lapse(:debuff), do: "It lifts in"
  defp lapse(:aura), do: "It settles in"
  defp lapse(_buff), do: "It holds for another"

  # The chronicle is read by whoever opened the page, so its pronouns are filled here, not when it
  # happened.
  defp voiced(line, mine?), do: Narrative.voiced(line, mine?)

  # Every ending is red, a suicide's too; a heresy is not an ending, and wears the Halls' cheat
  # colour. Spread rather than `class={...}`, which would print an empty class on every other line.
  defp deed_colour("ending"), do: [class: "deaths"]
  defp deed_colour("cheat"), do: [class: "heretics"]
  defp deed_colour(_deed), do: []

  # A class only on a row the stylesheet paints, each washed like the alert that would announce it.
  defp painted(%{kind: "fight", ambushed: true}), do: [class: "ambushed"]
  defp painted(%{kind: "start"}), do: [class: "start"]
  defp painted(%{kind: "level_up"}), do: [class: "level-up"]
  defp painted(%{kind: "class_change"}), do: [class: "class-change"]
  defp painted(%{kind: kind}) when kind in ~w(purchase dye), do: [class: "purchase"]
  defp painted(_entry), do: []

  # Every ending is an Ending, however it came: the pair of the Beginning.
  defp kind_label(%{kind: "fight"}), do: "Battle"
  defp kind_label(%{kind: "ending"}), do: "Ending"
  defp kind_label(%{kind: "start"}), do: "Beginning"
  defp kind_label(%{kind: "purchase"}), do: "Purchase"
  defp kind_label(%{kind: "level_up"}), do: "Level Up"
  defp kind_label(%{kind: "class_change"}), do: "Class Transfer"
  defp kind_label(%{kind: "dye"}), do: "Symbol"
  defp kind_label(%{kind: "cheat"}), do: "Cheat"
  defp kind_label(%{kind: "buff"}), do: "Buff"
  defp kind_label(%{kind: "debuff"}), do: "Debuff"

  attr :record_log, :list, default: []
  attr :record_id, :string, required: true
  # Whether entries older than the last one held remain to be asked for.
  attr :older, :boolean, default: false
  # Whose chronicle this is, which decides whether it is told to them or about them.
  attr :mine, :boolean, default: true

  @doc """
  A run's chronicle, newest first, in a panel of its own beside the record's; where the two stack
  it folds, and starts folded on every visit, so its length never crowds out the record.
  """
  def chronicle(assigns) do
    ~H"""
    <Controls.panel
      id="chronicle"
      title="The Chronicle"
      collapsible
      collapsed
      remember={false}
      subject={@record_id}
      scrolls
      log={:newest_first}
      load_older="older_chronicle"
      at_present="chronicle_at_present"
      unread={{"new entry", "new entries"}}
      body_class={@record_log != [] && "rows"}
    >
      <%= if @record_log == [] do %>
        <p class="last">Not one blow struck. This tale is over before it began.</p>
      <% else %>
        <%!-- An id per row, so a page put in front moves the rows held rather than rewriting them,
              and the hook can find the one the reader was looking at again. --%>
        <ol
          id="chronicle-log"
          class="chronicle"
          {stamps()}
          data-older-than={@older && List.last(@record_log).id}
        >
          <li
            :for={entry <- @record_log}
            :key={entry.id}
            id={"chronicle-#{entry.id}"}
            {painted(entry)}
          >
            <div class="entry-head">
              <span><.stamp at={entry.at} form={:short} time /> &bull; {kind_label(entry)}</span>
              <span>&num;{entry.number}</span>
            </div>
            <%= if entry.kind == "fight" do %>
              <%!-- Every line the fight drew, in order, bar the two that were button labels. A
                    line added to `Narrative.build_battle/3` belongs here too. --%>
              <span :if={entry.narrative.crit_line}>{raw(voiced(entry.narrative.crit_line, @mine))} </span>{raw(
                voiced(entry.narrative.kill_line, @mine)
              )} {raw(voiced(entry.narrative.deflection_line, @mine))}
              {raw(voiced(entry.narrative.outcome_line, @mine))}
              <span :if={entry.narrative.ambush_line} class="threat">{raw(
                voiced(entry.narrative.ambush_line, @mine)
              )}</span>
            <% else %>
              <span {deed_colour(entry.kind)}>{raw(voiced(entry.line, @mine))}</span>
            <% end %>
          </li>
        </ol>
      <% end %>
    </Controls.panel>
    """
  end

  attr :entry, :any, required: true
  attr :dead, :boolean, required: true
  attr :at, :any, required: true
  attr :voice, :map, required: true

  @doc false
  # Both ends of the road, in order, as a sentence of its own. A run with no row says nothing
  # rather than an empty clause.
  defp road(%{entry: nil} = assigns), do: ~H""

  defp road(assigns) do
    ~H"""
    <span id="record-road" {stamps()} phx-no-format><%= case road_of(@dead, @entry) do %>
      <% :closed -> %>The road opened beneath {@voice.their} feet <.stamp id="record-set-out" at={@entry.inserted_at} on time at_time /> and closed over {@voice.object} <.stamp id="record-last" at={@at} on time at_time />.
      <% :open -> %>The road opened beneath {@voice.their} feet <.stamp id="record-set-out" at={@entry.inserted_at} on time at_time /> and last carried {@voice.object} <.stamp id="record-last" at={@at} on time at_time />.
      <% :lost -> %>The road opened beneath {@voice.their} feet <.stamp id="record-set-out" at={@entry.inserted_at} on time at_time /> and swallowed {@voice.object} after {@voice.them} were last sighted <.stamp id="record-last" at={@at} on time at_time />.
    <% end %></span>
    """
  end

  # `active` is "has a session", so a retired run is neither dead nor going: lost. Dead comes from
  # the view, which every push brings; the entry is read once, and only says who holds it.
  defp road_of(true, _entry), do: :closed
  defp road_of(false, %{active: true}), do: :open
  defp road_of(false, _missing), do: :lost

  # ---------------------------------------------------------------- the screen

  attr :view, :map, required: true
  attr :catalog, :map, required: true
  attr :character_id, :string, default: nil
  attr :record, :map, default: nil
  attr :record_view, :map, default: nil
  attr :from, :string, default: nil

  def screen(assigns) do
    ~H"""
    <.record
      view={@record_view}
      catalog={@catalog}
      entry={@record}
      mine={@record.id == @character_id}
    />

    <%!-- Back the way you came: the sidebar says "game", a board sends the lineage it was
          filtered to, and the unfiltered Halls say nothing. --%>
    <%= if @from == "game" do %>
      <.back_link started={@view.started} dead={@view.dead} />
    <% else %>
      <.halls_link race={came_from(@from, @catalog)} />
    <% end %>
    """
  end

  # Looked up rather than trusted: `from` arrives in the URL, and only a lineage the game knows
  # about may decide where a link points.
  defp came_from(slug, catalog) when is_binary(slug),
    do: Enum.find(catalog.races, &(&1.slug == slug))

  defp came_from(_slug, _catalog), do: nil
end
