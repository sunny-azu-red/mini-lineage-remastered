defmodule MiniLineageWeb.Screens.SymbolMaker do
  @moduledoc """
  The Symbol Maker: the dyes a run wears, each washable for its fee, and the ones its class may
  draw. Slots open with the first class transfer, two of them, and a third with the second.
  """
  use MiniLineageWeb, :html

  import MiniLineageWeb.Controls

  alias MiniLineage.Game.{Classes, Dyes, Format}

  attr :view, :map, required: true
  attr :picked, :string, default: nil

  def screen(assigns) do
    class = Classes.get(assigns.view.class_id)

    assigns =
      assign(assigns,
        class: class,
        slots: Dyes.slots(class),
        worn: Enum.map(assigns.view.dyes, &Dyes.get/1),
        offered: Dyes.for_class(class.id)
      )

    ~H"""
    <p>
      The Symbol Maker grinds her dyes and looks up.<br />
      <%= if @slots == 0 do %>
        "Come back after your first class transfer, and I will have room to draw on you."
      <% else %>
        "Ten dyes and my fee, and the symbol is yours. You have room for {@slots}."
      <% end %>
    </p>

    <%= if @worn != [] do %>
      <h2>🖋️ Your Symbols</h2>
      <.data_table id="worn-table">
        <:col class="name">Symbol</:col>
        <:col>Wash Away</:col>
        <tbody>
          <tr :for={{dye, slot} <- Enum.with_index(@worn)} id={"worn-#{slot}"}>
            <td class="name"><span class="item">{dye.name}</span></td>
            <td>
              <.button
                variant={:danger}
                size={:sm}
                phx-click="remove_dye"
                phx-value-slot={slot}
              >🪙 {Format.adena(dye.cancel_fee)}</.button>
            </td>
          </tr>
        </tbody>
      </.data_table>
    <% end %>

    <%= if @slots > 0 do %>
      <.data_table id="dye-table">
        <:col class="name">Dye</:col>
        <:col>Adena</:col>
        <tbody>
          <tr :for={dye <- @offered} id={"dye-#{dye.id}"}>
            <td class="name"><span class="item">{dye.name}</span></td>
            <td class="adena">🪙 {Format.adena(Dyes.cost(dye))}</td>
          </tr>
        </tbody>
      </.data_table>
    <% end %>

    <.select_action_form
      id="dye-form"
      event="draw_dye"
      name="dye_id"
      picked={@picked}
      placeholder="🚪 Home Town"
      options={
        Enum.map(@offered, fn dye ->
          %{
            value: to_string(dye.id),
            label: "Draw #{dye.name}",
            disabled?: length(@worn) >= @slots
          }
        end)
      }
      default_label="Return"
      active_label="🖋️ Draw"
    />
    """
  end
end
