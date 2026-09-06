defmodule MiniLineageWeb.GameLive do
  @moduledoc """
  The single game LiveView. It holds no authoritative state: the character's process does, so a
  disconnect, a refresh or a second tab all read the same live character.

  Every navigation passes through `Access.pin_screen/2` in `handle_params/3`, so an in-app link, a
  typed URL and the Back button obey one set of rules.
  """
  use MiniLineageWeb, :live_view

  alias MiniLineage.Characters
  require Logger

  alias MiniLineage.Game.{Access, Actions, RateLimit, Snapshot, Version}
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
       statistics: nil,
       key_buffer: [],
       error_detail: nil,
       picked: nil
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
    socket = assign(socket, screen: screen, picked: nil, page_title: Screens.page_title(screen))

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
  # An explicit click into Battle IS a user action, so it fights immediately — never on load.
  # Its own clause: written as one `if`, the `{:noreply, _}` wrapper ended up inside the else
  # branch, so travelling to Battle returned a bare socket and took the LiveView down.
  def handle_event("navigate", %{"to" => "battle"}, socket) do
    handle_event("fight", %{}, push_patch(socket, to: Paths.for_screen("battle")))
  end

  def handle_event("navigate", %{"to" => screen}, socket) do
    {:noreply, push_patch(socket, to: Paths.for_screen(screen))}
  end

  def handle_event("start", %{"name" => name, "race_id" => race_id}, socket) do
    {:noreply, socket |> apply_action(&Actions.start(&1, race_id, name)) |> go("home")}
  end

  def handle_event("fight", _params, socket) do
    case throttle(socket, :battle) do
      {:ok, socket} ->
        socket = apply_action(socket, &Actions.fight/1)

        {:noreply, if(socket.assigns.player.dead, do: go(socket, "death"), else: socket)}

      {:limited, socket} ->
        {:noreply, socket}
    end
  end

  def handle_event("purchase", %{"item_id" => ""}, socket), do: {:noreply, go(socket, "home")}

  def handle_event("purchase", %{"item_id" => item_id, "type" => type}, socket) do
    case throttle(socket, :shop) do
      {:ok, socket} ->
        # Passed through as-is: Actions.purchase/3 is the boundary and validates it.
        {:noreply, apply_action(socket, &Actions.purchase(&1, type, item_id))}

      {:limited, socket} ->
        {:noreply, socket}
    end
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

  # `_target` names the field that changed, so one handler serves every action form.
  def handle_event("pick", %{"_target" => [field]} = params, socket),
    do: {:noreply, assign(socket, picked: params[field])}

  def handle_event("dismiss_flash", _params, socket),
    do: {:noreply, assign(socket, game_flash: nil, notice: nil)}

  # The Konami buffer lives here rather than in the character, so nothing about the sequence is
  # persisted and a second tab cannot half-complete it.
  def handle_event("key", %{"key" => key}, socket) do
    sequence = MiniLineage.Game.Constants.konami_sequence()
    buffer = Enum.take(socket.assigns.key_buffer ++ [key], -length(sequence))

    if buffer == sequence,
      do: {:noreply, socket |> assign(key_buffer: []) |> apply_action(&Actions.cheat/1)},
      else: {:noreply, assign(socket, key_buffer: buffer)}
  end

  # ----------------------------------------------------------------- pushes

  @impl true
  def handle_info({:character_updated, player}, socket),
    do: {:noreply, assign(socket, player: player, view: Snapshot.build(player))}

  # ------------------------------------------------------------------ plumbing

  # Runs an action in the character's process, then folds its result into the view.
  #
  # A genuinely unexpected failure lands on the error screen rather than taking the LiveView down
  # and silently remounting. `catch` covers the character process exiting, which reaches the
  # caller as an exit rather than a raise.
  defp apply_action(socket, fun) do
    id = socket.assigns.character_id
    result = Characters.mutate(id, fun)
    player = Characters.snapshot(id)

    socket
    |> assign(player: player, view: Snapshot.build(player))
    |> absorb(result)
  rescue
    error ->
      Logger.error(Exception.format(:error, error, __STACKTRACE__))
      fail(socket, Exception.message(error))
  catch
    :exit, reason ->
      Logger.error("character process exited: #{inspect(reason)}")
      fail(socket, "the character process exited: #{inspect(reason)}")
  end

  # The detail is withheld from a release build: a deployed game must never hand a player a stack.
  defp fail(socket, detail) do
    detail = unless Version.release?(Version.current()), do: detail

    socket |> assign(error_detail: detail) |> go("error")
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

  # Wording is chosen from the CURRENT ambush state rather than from the limiter, which carries
  # only one generic message. Flavour, not security.
  defp throttle(socket, limiter) do
    case RateLimit.check(socket.assigns.character_id, limiter) do
      :ok ->
        {:ok, socket}

      {:error, retry_after_ms} ->
        seconds = max(1, ceil(retry_after_ms / 1000))

        message =
          if socket.assigns.view[:ambushed] && !socket.assigns.view[:dead] do
            "You are in the middle of an ambush and moving too fast, please wait a moment."
          else
            "You are moving too fast, please take a breath and try again in #{seconds}s."
          end

        {:limited, assign(socket, notice: message)}
    end
  end

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
        phx-hook="PanelFocus"
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
          detail={@error_detail}
          picked={@picked}
        />
      </div>
    </Layouts.app>
    """
  end
end
