defmodule MiniLineageWeb.Screens.Shop do
  @moduledoc """
  The Inn, the Weapon Shop and the Armor Shop: one table and one picker, three sets of words for
  what is on offer and what the column beside the price means.
  """
  use MiniLineageWeb, :html

  import MiniLineageWeb.Controls

  alias MiniLineage.Game.Format

  attr :screen, :string, required: true
  attr :view, :map, required: true
  attr :catalog, :map, required: true
  attr :picked, :string, default: nil

  def screen(%{screen: "inn"} = assigns), do: assigns |> inn() |> table()
  def screen(%{screen: "weapons"} = assigns), do: assigns |> weapons() |> table()
  def screen(%{screen: "armors"} = assigns), do: assigns |> armors() |> table()

  defp inn(assigns) do
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
      stat_class: "heal",
      stat_header: "HP Heal",
      stat_title: "Share of Max HP restored",
      stat_suffix: "%",
      action_label: "🪙 Order",
      intro_a: "You have arrived at the Inn.",
      intro_b: "The young lady greets you and sets you at a table."
    )
  end

  defp weapons(assigns) do
    assign(assigns,
      type: "weapon",
      items: tl(assigns.catalog.weapons),
      owned_id: assigns.view.weapon.id,
      modifier: %{
        key: :crit,
        header: "Critical",
        title: "Critical Rate",
        class: "crit",
        prefix: "+",
        suffix: ""
      },
      stat_class: "hp",
      stat_header: "P. Attack",
      stat_title: "Physical Attack",
      stat_suffix: "",
      action_label: "🪙 Purchase",
      intro_a: "You have arrived at the Weapon Shop.",
      intro_b: "The nice man greets you and lets you look through his swords."
    )
  end

  defp armors(assigns) do
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
      stat_class: "defense",
      stat_header: "P. Defense",
      stat_title: "Physical Defense",
      stat_suffix: "",
      action_label: "🪙 Purchase",
      intro_a: "You have arrived at the Armor Shop.",
      intro_b: "The old man greets you and lets you look through his armors."
    )
  end

  defp table(assigns) do
    ~H"""
    <p>{@intro_a}<br />{@intro_b}</p>

    <%!-- Unsorted: figures rising with the price have one order worth reading. `raw/1` for the
          labels' entities; they are this module's constants, never anything a player typed. --%>
    <.data_table id={"#{@type}-table"}>
      <:col class="name">Name</:col>
      <:col class="num" title={@modifier.title}>{raw(@modifier.header)}</:col>
      <:col class="num" title={@stat_title}>{raw(@stat_header)}</:col>
      <:col>Adena</:col>
      <tbody>
        <%!-- Spread rather than a class list, which would print class="" on every other row. --%>
        <tr :for={item <- @items} {if @owned_id == item.id, do: [class: "owned"], else: []}>
          <td class="name">{item.emoji} <span class="item">{item.name}</span></td>
          <td class="num">
            <span :if={(Map.get(item, @modifier.key) || 0) > 0} class={@modifier.class}>
              {@modifier.prefix}{Map.get(item, @modifier.key)}{@modifier.suffix}
            </span>
            <span :if={(Map.get(item, @modifier.key) || 0) <= 0} class="muted">-</span>
          </td>
          <td class={["num", @stat_class]}>{Format.number(item.stat)}{@stat_suffix}</td>
          <td class="adena">🪙 {Format.adena(item.cost)}</td>
        </tr>
      </tbody>
    </.data_table>

    <.select_action_form
      id="purchase-form"
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
end
