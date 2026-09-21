defmodule MiniLineageWeb.Screens.Record do
  @moduledoc """
  One run's whole story, at `/character/:id`. Public because it is on the board, so there is
  nothing here to gate — yours is simply the one whose id matches your session's.
  """
  use MiniLineageWeb, :html

  import MiniLineageWeb.Controls

  alias MiniLineageWeb.Controls

  alias MiniLineage.Game.Format

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

    # Numbers named up here so each stat and its punctuation fit on one line below. The HEEx
    # formatter breaks a long line at a tag boundary, and a newline there renders as a space —
    # which is how "Physical Defense ." happens.
    assigns =
      assign(assigns,
        race: race,
        opponent: opponent,
        dead: assigns.view.dead,
        voice: voice(assigns.mine),
        # Only the tense moves between a run still going and one that is over.
        defined: if(assigns.view.dead, do: "was", else: "has been"),
        fought: if(assigns.view.dead, do: "fought", else: "have fought"),
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
    # tense moves. The closing paragraph forks outright — its sentences change shape, not just
    # verbs, since there is no next level to reach and no journey ahead.
    ~H"""
    <%!-- One hook over the whole record: it counts every [data-value] beneath it. Every figure is
          one, including the ones that move by a single step today — measured, a tween of +1 shows
          the old number for 137ms and then the new one, which is a delay and not a flicker, and
          forty at once hold 60fps. What an item grants counts too — buy a better blade while
          somebody is reading this and the figure climbs. Only the item's own name and the dates
          jump, having nothing to count through. --%>
    <div id="record-figures" phx-hook="AnimatedValues">
      <h2>{@race.emoji} {@view.name} of {@race.label} Ancestry</h2>
      <p>{raw(@race.backstory)}</p>
      <p>{raw(@race.traits)}</p>

      <h2>Inventory &amp; Stats</h2>
      <p phx-no-format>
        {@voice.they} {if @dead, do: "were wielding", else: "are wielding"} the {@view.weapon.emoji} <strong>{@view.weapon.name}</strong> granting
        <span class="hp"><span id="char-stat-attack" data-key="rec-attack" data-value={@view.stats.attack}>{@attack}</span> Physical Attack</span><%= if (@view.weapon.crit || 0) > 0 do %> and <span class="crit">+<span data-key="rec-weapon-crit" data-value={@view.weapon.crit}>{@view.weapon.crit}</span>% Critical Hit Chance</span><% end %>, and {if @dead, do: "wore", else: "wearing"} the {@view.armor.emoji} <strong>{@view.armor.name}</strong> providing
        <span class="defense"><span id="char-stat-defense" data-key="rec-defense" data-value={@view.stats.defense}>{@defense}</span> Physical Defense</span><%= if (@view.armor.regen || 0) > 0 do %> and <span class="heal">+<span data-key="rec-armor-regen" data-value={@view.armor.regen}>{@view.armor.regen}</span> HP Regeneration</span><% end %>.
      </p>
      <p>
        Combined with {@voice.their} ancestry, {@voice.them} {if @dead, do: "struck", else: "strike"} with a total of
        <span class="crit"><span id="char-stat-crit" data-key="rec-crit" data-value={@view.stats.crit}>{@crit}</span>% Critical Hit Chance</span>
        and {if @dead, do: "mended", else: "mend"} wounds at
        <span class="heal">+<span
          id="char-stat-regen"
          data-key="rec-regen"
          data-value={@view.stats.regen}
        >{@regen}</span>
        HP Regeneration</span>
        per rest cycle, while navigating the roads with a <span class="minor"><span id="char-stat-ambush" data-key="rec-ambush" data-value={@view.stats.ambush_risk}>{@ambush}</span>% Ambush Risk</span>.
      </p>

      <h2>{if @dead, do: "#{@voice.whose} Journey Has Ended", else: "The Journey So Far"}</h2>
      <p>
        {@voice.whose} journey across the realm {@defined} defined by conflict and survival<.road
          entry={@entry}
          at={@view.last_action_at}
          voice={@voice}
        />
        {@voice.they} {@fought} through
        <Controls.counted
          key="rec-battles"
          count={@view.counters.total_battles}
          singular="battle"
          plural="battles"
        />, slaying
        <Controls.counted
          key="rec-slain"
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
            class="minor"
          />
        <% end %>
        along the way.
      </p>

      <%= if @dead do %>
        <p phx-no-format>
        {@voice.they} fell at <span class="gold">Level <span data-key="rec-level" data-value={@view.level}>{@level}</span></span>
        with a total of <span class="xp"><span data-key="rec-xp" data-value={@view.experience}>{@experience}</span> XP</span><%= if @view.is_max_level do %>, standing unchallenged at the zenith of martial prowess<% else %>, <span class="xp"><span data-key="rec-xp-needed" data-value={@view.xp_needed}>{@xp_needed}</span> XP</span> short of <span class="gold">Level <span data-key="rec-next-level" data-value={@view.level + 1}>{@next_level}</span></span><% end %>, and {@voice.their} purse held <span class="gold">🪙 <span data-key="rec-adena" data-format="adena" data-value={@view.adena}>{@purse}</span> Adena</span>
        when the road ran out.
      </p>
        <p class="hp">{@view.death_reason}</p>
      <% else %>
        <%!-- The hook animates every [data-value] beneath it, so the HP figure counts as it regenerates. --%>
        <p id="char-vitality" phx-hook="AnimatedValues" phx-no-format>
        Experience wise, {@voice.them} are at <span class="gold">Level <span data-key="rec-level" data-value={@view.level}>{@level}</span></span>
        with a total of <span class="xp"><span data-key="rec-xp" data-value={@view.experience}>{@experience}</span> XP</span><%= if @view.is_max_level do %>, standing unchallenged at the zenith of martial prowess<% else %>, requiring another <span class="xp"><span data-key="rec-xp-needed" data-value={@view.xp_needed}>{@xp_needed}</span> XP</span> to reach <span class="gold">Level <span data-key="rec-next-level" data-value={@view.level + 1}>{@next_level}</span></span><% end %>
        and {@voice.their} vitality currently sustains {@voice.object} at
        <span class="hp"><span
          id="char-hp"
          data-key="char-hp"
          data-value={@view.health}
        >{Format.number(@view.health)}</span>
        / <span id="char-max-hp" data-key="rec-max-hp" data-value={@view.max_health}>{Format.number(@view.max_health)}</span>
        HP</span>
        while {@voice.their} purse holds <span class="gold">🪙 <span data-key="rec-adena" data-format="adena" data-value={@view.adena}>{@purse}</span> Adena</span>
        for the journey ahead.
      </p>
      <% end %>
    </div>
    """
  end

  attr :record_log, :list, default: []

  @doc """
  A run's fights, in a panel of their own beneath the record's. Longer than everything else on the
  page put together, so inside the panel they crowd out what the panel is named for.
  """
  def chronicle(assigns) do
    ~H"""
    <Controls.panel
      id="chronicle"
      title="The Chronicle"
      collapsible
      collapsed
      max_height={260}
      stick_to_bottom
      body_class="rows"
    >
      <%= if @record_log == [] do %>
        <p class="last">Not one blow struck. This tale is over before it began.</p>
      <% else %>
        <%!-- Every line the fight drew, in the order it drew them, bar the two that are button
              labels rather than history. A line added to `Narrative.build_battle/3` belongs here
              too, or the chronicle quietly stops telling the whole of it. --%>
        <ol class="chronicle">
          <li
            :for={fight <- @record_log}
            {if fight.ambushed, do: [class: "ambushed"], else: []}
          >
            <span :if={fight.narrative.crit_line}>{raw(fight.narrative.crit_line)} </span>{raw(
              fight.narrative.kill_line
            )} {raw(fight.narrative.deflection_line)} {raw(fight.narrative.outcome_line)}
            <span :if={fight.narrative.ambush_line}>{raw(fight.narrative.ambush_line)}</span>
          </li>
        </ol>
      <% end %>
    </Controls.panel>
    """
  end

  # Your own page speaks to you; somebody else's speaks about them. They/them is not only the right
  # default for a character whose gender the game never records — it also takes the same verb forms
  # as "you", so nothing but the pronouns moves between the two.
  defp voice(true),
    do: %{they: "You", them: "you", object: "you", their: "your", whose: "Your"}

  defp voice(false),
    do: %{they: "They", them: "they", object: "them", their: "their", whose: "Their"}

  attr :entry, :any, required: true
  attr :at, :any, required: true
  attr :voice, :map, required: true

  @doc false
  # How the sentence above ends, carrying both ends of the road. It owns the full stop because a run
  # with no row has no road to describe and the sentence has to close anyway. Its own component so
  # each line stays whole: the formatter breaks at a tag, and a newline before the stop reads " .".
  defp road(%{entry: nil} = assigns), do: ~H"."

  defp road(assigns) do
    ~H"""
    <span phx-no-format><%= case road_of(@entry) do %>
      <% :closed -> %> with the road opening beneath {@voice.their} feet on <.stamp id="record-set-out" at={@entry.inserted_at} /> and closing over {@voice.object} on <.stamp id="record-last" at={@at} />.
      <% :open -> %> with the road opening beneath {@voice.their} feet on <.stamp id="record-set-out" at={@entry.inserted_at} />, and last carrying {@voice.object} on <.stamp id="record-last" at={@at} />.
      <% :lost -> %> with the road opening beneath {@voice.their} feet on <.stamp id="record-set-out" at={@entry.inserted_at} />, and swallowing {@voice.object} somewhere past <.stamp id="record-last" at={@at} />.
    <% end %></span>
    """
  end

  # Three ways a road ends: closed over them, still open, or lost with them still on it. `active` is
  # "has a session", so a run walked away from past the retirement window is neither dead nor going —
  # and the only one of the three whose last date names a direction rather than a day.
  defp road_of(%{dead: true}), do: :closed
  defp road_of(%{active: true}), do: :open
  defp road_of(_missing), do: :lost

  # ---------------------------------------------------------------- the screen

  attr :view, :map, required: true
  attr :catalog, :map, required: true
  attr :character_id, :string, default: nil
  attr :record, :map, default: nil
  attr :record_view, :map, default: nil
  attr :from, :string, default: nil

  def screen(%{record: nil} = assigns) do
    ~H"""
    <p>
      No such name is written here. The Hall keeps only those who drew a blade, and this one either
      never did or was never real.
    </p>

    <.halls_link race={came_from(assigns)} />
    """
  end

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
      <.halls_link race={came_from(assigns)} />
    <% end %>
    """
  end

  # Looked up rather than trusted: `from` arrives in the URL, and only a lineage the game knows
  # about may decide where a link points.
  defp came_from(%{from: slug, catalog: catalog}) when is_binary(slug),
    do: Enum.find(catalog.races, &(&1.slug == slug))

  defp came_from(_assigns), do: nil
end
