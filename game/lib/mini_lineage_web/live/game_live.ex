defmodule MiniLineageWeb.GameLive do
  @moduledoc """
  The single game LiveView. It holds no authoritative state: the character's process does, so a
  disconnect, a refresh or a second tab all read the same live character.
  """
  use MiniLineageWeb, :live_view

  alias MiniLineage.Characters
  alias MiniLineage.Game.{Constants, Player}

  @impl true
  def mount(_params, session, socket) do
    id = session["character_id"]

    if connected?(socket) do
      Characters.attach(id)
      Characters.subscribe(id)
    end

    {:ok, assign(socket, character_id: id, player: Characters.snapshot(id))}
  end

  @impl true
  def handle_event("start", %{"name" => name, "race_id" => race_id}, socket) do
    with {race_id, ""} <- Integer.parse(race_id),
         true <- race_id in 0..(length(Constants.races()) - 1),
         name when byte_size(name) > 0 <-
           String.slice(String.trim(name), 0, Constants.character().name_max_length) do
      player =
        Characters.mutate(socket.assigns.character_id, fn player ->
          if Player.started?(player) do
            {player, player}
          else
            {player, _flash} = Player.initialize(player, Constants.race(race_id), name)
            player = %{player | current_screen: "home"}
            {player, player}
          end
        end)

      {:noreply, assign(socket, player: player)}
    else
      _ -> {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:character_updated, player}, socket),
    do: {:noreply, assign(socket, player: player)}

  @impl true
  def render(assigns) do
    assigns = assign(assigns, started?: Player.started?(assigns.player))

    ~H"""
    <Layouts.app flash={@flash} title={if @started?, do: "Town", else: "Game Start"}>
      <div id="screen" data-screen={if @started?, do: "home", else: "start"}>
        <%= if @started? do %>
          <p>
            <span data-role="name">{@player.name}</span>
            &mdash; <span data-role="hp">{@player.health}</span>/<span data-role="max-hp">{Player.stats(
              @player
            ).max_health}</span>
            HP
            &mdash; <span data-role="adena">{@player.adena}</span>
            Adena
          </p>
          <p class="muted">Screens arrive in phase 3.</p>
        <% else %>
          <form phx-submit="start">
            <input
              type="text"
              name="name"
              placeholder="Name your character"
              maxlength={Constants.character().name_max_length}
              required
            />
            <select name="race_id">
              <option :for={race <- Constants.races()} value={race.id}>
                {race.emoji} {race.label}
              </option>
            </select>
            <button type="submit">Begin</button>
          </form>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
