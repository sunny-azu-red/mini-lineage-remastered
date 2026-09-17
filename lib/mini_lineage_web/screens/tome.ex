defmodule MiniLineageWeb.Screens.Tome do
  @moduledoc "The Tome of Lore: every lifetime counter, told as the realm's own history."
  use MiniLineageWeb, :html

  import MiniLineageWeb.Controls

  alias MiniLineage.Game.Format

  attr :view, :map, required: true
  attr :statistics, :map, default: nil

  def screen(assigns) do
    ~H"""
    <%= if @statistics do %>
      <h2>The Legacy of the Realm</h2>
      <p>
        In the age of steel and magic,
        <span class="tally">{Format.pluralize("Brave Soul", "Brave Souls", @statistics.total_players)}</span>
        {verb(@statistics.total_players, "has", "have")} set foot upon these dangerous lands. Through
        hardship and triumph, they have collectively ascended
        <span class="gold">{Format.pluralize("Level", "Levels", @statistics.total_levels_gained)}</span>
        in their pursuit of power. Yet, glory always exacts a price, because
        <span class="hp">{Format.pluralize("Champion", "Champions", @statistics.total_deaths)}</span>
        {verb(@statistics.total_deaths, "has", "have")} fallen in battle... lost, but not forgotten.
      </p>
      <p>
        A few, overwhelmed by the weight of their journey, chose the coward's end, with
        <span class="minor">
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
        <span class="tally">{Format.pluralize("Battle", "Battles", @statistics.total_battles)}</span>
        {verb(@statistics.total_battles, "has", "have")} been fought against the encroaching darkness,
        resulting in the defeat of
        <span class="tally">
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
        <span class="minor">{Format.pluralize("Ambush", "Ambushes", @statistics.total_ambushes)}</span>
        {verb(@statistics.total_ambushes, "has", "have")} occurred, nearly claiming those who walked
        unprepared.
      </p>

      <h2>The Toll of Survival</h2>
      <p>
        Hardship is measured in blood and resilience. Our champions have shed <span class="hp">{Format.number(@statistics.total_hp_lost)} HP</span>, flesh torn by tooth and
        claw. Yet, the craft of the blacksmith has proven its worth, as armor deflected <span class="defense">{Format.number(@statistics.total_damage_blocked)} Damage</span>.
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
        <span class="tally">{Format.pluralize("Weapon", "Weapons", @statistics.total_weapons_bought)}</span>
        and
        <span class="tally">{Format.pluralize("Armor", "Armors", @statistics.total_armors_bought)}</span>
        to those who would be king, while the local Inn has served
        <span class="tally">{Format.pluralize("Meal", "Meals", @statistics.total_food_bought)}</span>
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

  defp verb(1, singular, _plural), do: singular
  defp verb(_count, _singular, plural), do: plural
end
