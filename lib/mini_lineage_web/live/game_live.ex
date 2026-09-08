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

  alias MiniLineage.Game.{Access, Actions, Player, RateLimit, Snapshot, Version}
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
       picked: nil,
       flash_fresh: false
     )}
  end

  # ------------------------------------------------------------- navigation

  @impl true
  def handle_params(params, _uri, socket) do
    requested = requested_screen(socket.assigns.live_action, socket.assigns.player)
    pinned = Access.pin_screen(requested, socket.assigns.player)

    # An unrecognised path patches even when it resolved to where we already are, so the address bar
    # never keeps a URL the game does not own.
    if pinned != requested or socket.assigns.live_action == :unknown do
      {:noreply, push_patch(socket, to: Paths.for_screen(pinned), replace: true)}
    else
      {:noreply, socket |> assign_race_filter(params) |> enter(pinned)}
    end
  end

  # '/' and any unrecognised path both mean Game Start for a visitor and Town for a character;
  # every other route names itself.
  defp requested_screen(action, player) when action in [:root, :unknown],
    do: if(MiniLineage.Game.Player.started?(player), do: "home", else: "start")

  defp requested_screen(action, _player), do: Atom.to_string(action)

  defp assign_race_filter(socket, %{"race" => slug}) do
    race = Enum.find(socket.assigns.catalog.races, &(&1.slug == slug))

    assign(socket, race_filter: race && race.id)
  end

  # Cleared, not left alone: "All" is simply /highscores with no race in the path, so a filter that
  # survives the trip means the button appears to do nothing.
  defp assign_race_filter(socket, _params), do: assign(socket, race_filter: nil)

  # Reporting the screen is what drives the combat/resting auras, so it must happen on arrival.
  defp enter(socket, screen) do
    # `game_flash` is one-shot, tied to the action that produced it — leaving the screen drops it.
    # A notice is not: it reports a refusal, and survives until dismissed or superseded.
    #
    # An action that both flashes AND moves you (creating a character, dying) would otherwise
    # clear its own message on the way, so a flash set by this navigation survives exactly one
    # arrival. The reference achieves the same by setting flash and screen in one update.
    socket =
      if socket.assigns[:flash_fresh],
        do: assign(socket, flash_fresh: false),
        else: assign(socket, game_flash: nil)

    socket = assign(socket, screen: screen, picked: nil, page_title: Screens.page_title(screen))

    if connected?(socket) and Player.started?(socket.assigns.player) do
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
    handle_event("fight", %{}, leave(socket, "battle"))
  end

  def handle_event("navigate", %{"to" => screen}, socket) do
    {:noreply, leave(socket, screen)}
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

  def handle_event("purchase", %{"item_id" => ""}, socket), do: {:noreply, leave(socket, "home")}

  def handle_event("purchase", %{"item_id" => item_id, "type" => type}, socket) do
    case throttle(socket, :shop) do
      {:ok, socket} ->
        # `picked: nil` puts the select back on "🚪 Home Town" once the shop has answered —
        # after a refusal too, matching the reference, which remounts the form on any completed
        # attempt rather than only a successful one.
        socket = apply_action(socket, &Actions.purchase(&1, type, item_id))

        {:noreply, assign(socket, picked: nil)}

      {:limited, socket} ->
        {:noreply, socket}
    end
  end

  def handle_event("suicide", %{"confirm" => "yes"}, socket),
    do: {:noreply, socket |> apply_action(&Actions.suicide/1) |> go("death")}

  def handle_event("suicide", _params, socket), do: {:noreply, leave(socket, "home")}

  def handle_event("submit_highscore", _params, socket) do
    socket = apply_action(socket, &Actions.submit_highscore/1)
    slug = get_in(socket.assigns, [:last_result, :race_slug])

    {:noreply, go(socket, "highscores", slug)}
  end

  def handle_event("restart", _params, socket),
    do: {:noreply, socket |> apply_action(&Actions.restart/1) |> go("start")}

  # `_target` names the field that changed, so one handler serves every action form.
  def handle_event("pick", %{"_target" => [field]} = params, socket),
    do: {:noreply, assign(socket, picked: params[field])}

  def handle_event("dismiss_notice", _params, socket), do: {:noreply, assign(socket, notice: nil)}

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
  def handle_info({:character_updated, player}, socket) do
    # A push can invalidate where this tab is standing: another tab restarts the character, or the
    # server kills it. Re-pin against the new player, and treat a reset as a trip back to Game
    # Start rather than leaving this tab on a screen its character no longer qualifies for.
    reset? = Player.started?(socket.assigns.player) and not Player.started?(player)
    socket = assign(socket, player: player, view: Snapshot.build(player))
    target = Access.pin_screen(if(reset?, do: "start", else: socket.assigns.screen), player)

    {:noreply, if(target == socket.assigns.screen, do: socket, else: leave(socket, target))}
  end

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
    do:
      socket
      |> assign(notice: nil, game_flash: flash, last_result: nil)
      |> play(flash[:sound])

  defp absorb(socket, {:ok, result}) do
    flash = Map.get(result, :flash)

    socket
    |> assign(notice: nil, game_flash: flash, last_result: result)
    |> play(Map.get(result, :sound))
  end

  defp play(socket, nil), do: socket
  defp play(socket, sound), do: push_event(socket, "play-sound", %{name: sound})

  # An action moved you, so its flash comes along — creating a character lands on Town with its
  # welcome, dying lands on the death screen with its reason.
  defp go(socket, screen, race_slug \\ nil) do
    socket
    |> assign(flash_fresh: true)
    |> push_patch(to: Paths.for_screen(screen, race_slug))
  end

  # The PLAYER moved themselves, so nothing comes along. A link or the banner reaches
  # handle_params with no flag at all and is dropped there; these events need saying so, because
  # a flash from an earlier action is still sitting in the assigns.
  defp leave(socket, screen), do: socket |> assign(game_flash: nil) |> go(screen)

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
      <Screens.low_health :if={Screens.low_health_alert?(@view, @screen)} ambushed={@view.ambushed} />

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
    </Layouts.app>
    """
  end
end
