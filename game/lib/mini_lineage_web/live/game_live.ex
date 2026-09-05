defmodule MiniLineageWeb.GameLive do
  @moduledoc """
  The single game LiveView. It holds no authoritative state: the character's process does, so a
  disconnect, a refresh or a second tab all read the same live character.

  Every navigation passes through `Access.pin_screen/2` in `handle_params/3`, so an in-app link, a
  typed URL and the Back button obey one set of rules.
  """
  use MiniLineageWeb, :live_view

  alias MiniLineage.Characters
  alias MiniLineage.Game.{Access, Actions, Snapshot}
  alias MiniLineage.Game.Statistics.Collector
  alias MiniLineage.Highscores
  alias MiniLineageWeb.{Paths, Screens}

  @impl true
  def mount(_params, session, socket) do
    id = session["character_id"]

    if connected?(socket) do
      Characters.attach(id)
      Characters.subscribe(id)
    end

    player = Characters.snapshot(id)

    {:ok,
     socket
     |> assign(
       character_id: id,
       player: player,
       view: Snapshot.build(player),
       catalog: Snapshot.catalog(),
       screen: "start",
       race_filter: nil,
       notice: nil,
       game_flash: nil,
       highscores: [],
       statistics: nil
     )}
  end

  # ------------------------------------------------------------- navigation

  @impl true
  def handle_params(params, _uri, socket) do
    requested = requested_screen(socket.assigns.live_action, socket.assigns.player)
    pinned = Access.pin_screen(requested, socket.assigns.player)

    if pinned != requested do
      {:noreply, push_patch(socket, to: Paths.for_screen(pinned), replace: true)}
    else
      {:noreply, socket |> assign_race_filter(params) |> enter(pinned)}
    end
  end

  # '/' means Game Start for a visitor and Town for a character; every other route names itself.
  defp requested_screen(:root, player),
    do: if(MiniLineage.Game.Player.started?(player), do: "home", else: "start")

  defp requested_screen(action, _player), do: Atom.to_string(action)

  defp assign_race_filter(socket, %{"race" => slug}) do
    race = Enum.find(socket.assigns.catalog.races, &(&1.slug == slug))

    assign(socket, race_filter: race && race.id)
  end

  defp assign_race_filter(socket, _params), do: socket

  # Reporting the screen is what drives the combat/resting auras, so it must happen on arrival.
  defp enter(socket, screen) do
    socket = assign(socket, screen: screen)

    if connected?(socket) and MiniLineage.Game.Player.started?(socket.assigns.player) do
      apply_action(socket, &Actions.set_screen(&1, screen))
    else
      socket
    end
    |> load_screen_data(screen)
  end

  defp load_screen_data(socket, "highscores"),
    do: assign(socket, highscores: Highscores.list(socket.assigns.race_filter))

  defp load_screen_data(socket, "statistics"),
    do: assign(socket, statistics: Collector.read_all())

  defp load_screen_data(socket, _screen), do: socket

  # ----------------------------------------------------------------- events

  @impl true
  def handle_event("navigate", %{"to" => screen}, socket) do
    # An explicit click into Battle IS a user action, so it fights immediately — never on load.
    socket = push_patch(socket, to: Paths.for_screen(screen))

    if screen == "battle",
      do: handle_event("fight", %{}, socket) |> elem(1),
      else:
        socket
        |> then(&{:noreply, &1})
  end

  def handle_event("start", %{"name" => name, "race_id" => race_id}, socket) do
    {:noreply, socket |> apply_action(&Actions.start(&1, race_id, name)) |> go("home")}
  end

  def handle_event("fight", _params, socket) do
    socket = apply_action(socket, &Actions.fight/1)

    {:noreply, if(socket.assigns.player.dead, do: go(socket, "death"), else: socket)}
  end

  def handle_event("purchase", %{"item_id" => ""}, socket), do: {:noreply, go(socket, "home")}

  def handle_event("purchase", %{"item_id" => item_id, "type" => type}, socket) do
    item_id = String.to_integer(item_id)

    {:noreply, apply_action(socket, &Actions.purchase(&1, type, item_id))}
  end

  def handle_event("suicide", %{"confirm" => "yes"}, socket),
    do: {:noreply, socket |> apply_action(&Actions.suicide/1) |> go("death")}

  def handle_event("suicide", _params, socket), do: {:noreply, go(socket, "home")}

  def handle_event("submit_highscore", _params, socket) do
    socket = apply_action(socket, &Actions.submit_highscore/1)
    slug = get_in(socket.assigns, [:last_result, :race_slug])

    {:noreply, push_patch(socket, to: Paths.for_screen("highscores", slug))}
  end

  def handle_event("restart", _params, socket),
    do: {:noreply, socket |> apply_action(&Actions.restart/1) |> go("start")}

  def handle_event("dismiss_flash", _params, socket),
    do: {:noreply, assign(socket, game_flash: nil, notice: nil)}

  # ----------------------------------------------------------------- pushes

  @impl true
  def handle_info({:character_updated, player}, socket),
    do: {:noreply, assign(socket, player: player, view: Snapshot.build(player))}

  # ------------------------------------------------------------------ plumbing

  # Runs an action in the character's process, then folds its result into the view.
  defp apply_action(socket, fun) do
    id = socket.assigns.character_id
    result = Characters.mutate(id, fun)
    player = Characters.snapshot(id)

    socket
    |> assign(player: player, view: Snapshot.build(player))
    |> absorb(result)
  end

  defp absorb(socket, {:error, _code, message}),
    do: assign(socket, notice: message, game_flash: nil)

  defp absorb(socket, {:ok, nil}), do: assign(socket, notice: nil, last_result: nil)

  defp absorb(socket, {:ok, %{text: _} = flash}),
    do: socket |> assign(notice: nil, game_flash: flash, last_result: nil) |> play(flash[:sound])

  defp absorb(socket, {:ok, result}) do
    socket
    |> assign(notice: nil, game_flash: Map.get(result, :flash), last_result: result)
    |> play(Map.get(result, :sound))
  end

  defp play(socket, nil), do: socket
  defp play(socket, sound), do: push_event(socket, "play-sound", %{name: sound})

  defp go(socket, screen), do: push_patch(socket, to: Paths.for_screen(screen))

  # ------------------------------------------------------------------ render

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} title={Screens.title(@screen)} view={@view} screen={@screen}>
      <Screens.notice :if={@notice} message={@notice} />
      <Screens.flash_alert :if={@game_flash} flash={@game_flash} />
      <Screens.low_health
        :if={
          @view.started && !@view.dead && @view.low_health && Screens.sidebar?(@screen) &&
            @screen not in ["suicide", "inn"]
        }
        ambushed={@view.ambushed}
      />

      <%!-- The character's live state, mirrored onto one element so a browser test can assert on
            game state rather than scraping prose. --%>
      <div
        id="screen"
        data-screen={@screen}
        data-started={to_string(@view.started)}
        data-dead={to_string(@view[:dead] || false)}
        data-ambushed={to_string(@view[:ambushed] || false)}
        data-level={@view[:level]}
        data-health={@view[:health]}
        data-max-health={@view[:max_health]}
        data-adena={@view[:adena]}
        data-battles={@view[:counters] && @view.counters.total_battles}
      >
        <Screens.screen
          screen={@screen}
          view={@view}
          catalog={@catalog}
          highscores={@highscores}
          statistics={@statistics}
          race_filter={@race_filter}
        />
      </div>
    </Layouts.app>
    """
  end
end
