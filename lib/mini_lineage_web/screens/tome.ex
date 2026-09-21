defmodule MiniLineageWeb.Screens.Tome do
  @moduledoc "The Tome of Lore: every lifetime counter, told as the realm's own history."
  use MiniLineageWeb, :html

  import MiniLineageWeb.Controls

  alias MiniLineage.Game.Format

  attr :view, :map, required: true
  attr :statistics, :map, default: nil

  def screen(assigns) do
    ~H"""
    <%!-- The archives move whenever the collector flushes, which with a realm full of players is a
          long way at a time — exactly what a count is for. --%>
    <div id="tome-figures" phx-hook="AnimatedValues">
      <%= if @statistics do %>
        <h2>The Legacy of the Realm</h2>
        <p>
          In the age of steel and magic,
          <.counted
            key="tome-players"
            count={@statistics.total_players}
            singular="Brave Soul"
            plural="Brave Souls"
            class="players"
          />
          {verb(@statistics.total_players, "has", "have")} set foot upon these dangerous lands. Through
          hardship and triumph, they have collectively ascended
          <.counted
            key="tome-levels-gained"
            count={@statistics.total_levels_gained}
            singular="Level"
            plural="Levels"
            class="level"
          /> in their pursuit of power. Yet, glory always exacts a price, because
          <.counted
            key="tome-deaths"
            count={@statistics.total_deaths}
            singular="Champion"
            plural="Champions"
            class="deaths"
          />
          {verb(@statistics.total_deaths, "has", "have")} fallen in battle... lost, but not forgotten.
        </p>
        <p>
          A few, overwhelmed by the weight of their journey, chose the coward's end, with
          <.counted
            key="tome-players-suicided"
            count={@statistics.total_players_suicided}
            singular="Weak Soul"
            plural="Weak Souls"
            class="cowards"
          />
          taking {verb(@statistics.total_players_suicided, "its own life", "their own lives")}, while
          <.counted
            key="tome-players-cheated"
            count={@statistics.total_players_cheated}
            singular="Heretic"
            plural="Heretics"
            class="heretics"
          />
          {verb(@statistics.total_players_cheated, "was", "were")} struck down by the gods for attempting
          to bypass the laws of the realm.
        </p>

        <h2>Echoes of the Battlefield</h2>
        <p>
          The drums of war never truly fall silent because
          <.counted
            key="tome-battles"
            count={@statistics.total_battles}
            singular="Battle"
            plural="Battles"
            class="battles"
          />
          {verb(@statistics.total_battles, "has", "have")} been fought against the encroaching darkness,
          resulting in the defeat of
          <.counted
            key="tome-enemies-killed"
            count={@statistics.total_enemies_killed}
            singular="Formidable Foe"
            plural="Formidable Foes"
            class="kills"
          /> through lethal precision and
          <.counted
            key="tome-critical-hits"
            count={@statistics.total_critical_hits}
            singular="Critical Strike"
            plural="Critical Strikes"
            class="crit"
          /> that turned the tide of every skirmish.
        </p>
        <p>
          From these conflicts, the survivors extracted vast wisdom, gaining a total of <span class="xp"><span data-key="tome-xp-gained" data-value={@statistics.total_xp_gained}>{Format.number(@statistics.total_xp_gained)}</span> XP</span>. But the wild is
          treacherous, as the hunters became the hunted and
          <.counted
            key="tome-ambushes"
            count={@statistics.total_ambushes}
            singular="Ambush"
            plural="Ambushes"
            class="ambush"
          />
          {verb(@statistics.total_ambushes, "has", "have")} occurred, nearly claiming those who walked
          unprepared.
        </p>

        <h2>The Toll of Survival</h2>
        <p>
          Hardship is measured in blood and resilience. Our champions have shed <span class="hp"><span data-key="tome-hp-lost" data-value={@statistics.total_hp_lost}>{Format.number(@statistics.total_hp_lost)}</span> HP</span>, flesh torn by tooth and
          claw. Yet, the craft of the blacksmith has proven its worth, as armor deflected <span class="damage"><span data-key="tome-damage-blocked" data-value={@statistics.total_damage_blocked}>{Format.number(@statistics.total_damage_blocked)}</span> Damage</span>.
        </p>
        <p>
          To mend their broken bodies, they have sought the warmth of the Inn and the delicious food
          inside, healing for a combined total of <span class="heal"><span data-key="tome-hp-healed" data-value={@statistics.total_hp_healed}>{Format.number(@statistics.total_hp_healed)}</span> HP</span>. In the stillness of
          sanctuary, where fine armor protects the weary, another
          <span class="regen"><span data-key="tome-hp-regen" data-value={@statistics.total_hp_regen}>{Format.number(
            @statistics.total_hp_regen
          )}</span>
          HP</span>
          was restored through the natural mending of the soul.
        </p>

        <h2>The Flow of Fortune</h2>
        <p>
          Wealth flows like a river through the pockets of the daring. A massive sum of
          <span class="adena">🪙
          <span
            data-key="tome-adena-generated"
            data-format="adena"
            data-value={@statistics.total_adena_generated}
          >{Format.adena(@statistics.total_adena_generated)}</span>
          Adena</span>
          has been pulled from the corpses of monsters and the hidden corners of the world. Most of this
          fortune, however, returns to the realm's economy since
          <span class="adena">🪙
          <span
            data-key="tome-adena-spent"
            data-format="adena"
            data-value={@statistics.total_adena_spent}
          >{Format.adena(@statistics.total_adena_spent)}</span>
          Adena</span>
          has been spent on provisions and equipment.
        </p>
        <p>
          The shops have flourished, selling
          <.counted
            key="tome-weapons-bought"
            count={@statistics.total_weapons_bought}
            singular="Weapon"
            plural="Weapons"
            class="purchases"
          /> and
          <.counted
            key="tome-armors-bought"
            count={@statistics.total_armors_bought}
            singular="Armor"
            plural="Armors"
            class="purchases"
          /> to those who would be king, while the local Inn has served
          <.counted
            key="tome-food-bought"
            count={@statistics.total_food_bought}
            singular="Meal"
            plural="Meals"
            class="purchases"
          /> to keep the fires of life burning.
        </p>
      <% else %>
        <p>
          The ancient archives are empty and the lore of the realm has been lost to time. The chronicles
          of the realm await their first dynasty. Will you be the one to start a new bloodline?
        </p>
      <% end %>
    </div>

    <.back_link started={@view.started} dead={@view.dead} />
    """
  end

  defp verb(1, singular, _plural), do: singular
  defp verb(_count, _singular, plural), do: plural
end
