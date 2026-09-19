defmodule MiniLineageWeb.GameLive do
  @moduledoc """
  The single game LiveView. It holds no authoritative state: the character's process does, so a
  disconnect, a refresh or a second tab all read the same live character.

  Every navigation passes through `Access.pin_screen/2` in `handle_params/3`, so an in-app link, a
  typed URL and the Back button obey one set of rules.
  """
  use MiniLineageWeb, :live_view

  alias MiniLineage.{BattleLog, Board, Characters}
  alias MiniLineage.Characters.Store
  require Logger

  alias MiniLineage.Game.{Access, Actions, Player, RateLimit, Snapshot, Version}
  alias MiniLineage.Game.Statistics.Collector
  alias MiniLineageWeb.{Paths, Screens}

  @impl true
  def mount(_params, %{"session_id" => id}, socket) when is_binary(id) do
    mount_character(id, socket)
  end

  # A cookie the plug never saw — a tab left open across a deploy. A LiveView cannot issue one, so
  # bounce through a real request. The plug always sets one, so this cannot come round twice.
  def mount(_params, _session, socket), do: {:ok, redirect(socket, to: ~p"/")}

  defp mount_character(id, socket) do
    if connected?(socket) do
      Characters.attach(id)
      Characters.subscribe(id)
      Board.subscribe()
      Collector.subscribe()
    end

    player = Characters.snapshot(id)

    {:ok,
     socket
     |> assign(
       session_id: id,
       # Public, fixed for the life of this session, and the only id that may be rendered.
       character_id: Characters.character_id(id),
       player: player,
       view: Snapshot.build(player),
       catalog: Snapshot.catalog(),
       screen: "start",
       race_filter: nil,
       notice: nil,
       game_flash: nil,
       boards: %{},
       record: nil,
       record_view: nil,
       watching: nil,
       record_log: [],
       from: nil,
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
      {:noreply,
       socket
       |> assign_race_filter(params)
       |> assign_record(params)
       |> assign_from(params)
       |> enter(pinned)}
    end
  end

  # '/' is wherever the player's own state puts them. Death is a state, not a place, so it has no
  # URL of its own — an ambush is different, being somewhere you can stand, and keeps one.
  defp requested_screen(action, player) when action in [:root, :unknown] do
    cond do
      player.dead -> "death"
      Player.started?(player) -> "home"
      true -> "start"
    end
  end

  defp requested_screen(action, _player), do: Atom.to_string(action)

  defp assign_race_filter(socket, %{"race" => slug}) do
    race = Enum.find(socket.assigns.catalog.races, &(&1.slug == slug))

    assign(socket, race_filter: race && race.id)
  end

  # Cleared, not left alone: "All" is simply /highscores with no race in the path, so a filter that
  # survives the trip means the button appears to do nothing.
  defp assign_race_filter(socket, _params), do: assign(socket, race_filter: nil)

  # Which hall is being read, so every place that names one says the same thing.
  defp filter_race(%{assigns: assigns}), do: filter_race(assigns)

  defp filter_race(%{race_filter: id, catalog: catalog}),
    do: Enum.find(catalog.races, &(&1.id == id))

  # A run nobody can find is not an error: `Screens` draws an empty state for a nil record. Yours
  # is read from your own process rather than the document, because `health` is buffered.
  defp assign_record(socket, %{"id" => id}) do
    entry = Board.entry(id)

    view =
      cond do
        is_nil(entry) -> nil
        entry.id == socket.assigns.character_id -> socket.assigns.view
        true -> entry.id |> Store.load() |> Snapshot.build()
      end

    socket
    |> watch_record(entry && entry.id)
    |> assign(
      record: entry,
      record_view: view,
      record_log: (entry && BattleLog.history(entry.id)) || []
    )
  end

  defp assign_record(socket, _params), do: socket |> watch_record(nil) |> clear_record()

  defp clear_record(socket),
    do: assign(socket, record: nil, record_view: nil, record_log: [])

  # A record is watched only while it is the screen. Patching from one to another leaves the first,
  # or a reader who walked the Halls would end up holding every record they opened.
  defp watch_record(socket, id) do
    case socket.assigns[:watching] do
      ^id ->
        socket

      previous ->
        if previous, do: Characters.unwatch_record(previous)
        if id && connected?(socket), do: Characters.watch_record(id)
        assign(socket, watching: id)
    end
  end

  # Where the reader came from, so the record can send them back there.
  defp assign_from(socket, %{"from" => from}), do: assign(socket, from: from)
  defp assign_from(socket, _params), do: assign(socket, from: nil)

  # Reporting the screen is what drives the combat/resting auras, so it must happen on arrival.
  defp enter(socket, screen) do
    # A flash belongs to the action that produced it and survives exactly one arrival, so an action
    # that both flashes and moves you — creating a character, dying — does not clear its own
    # message on the way. A notice is different: it reports a refusal and waits to be dismissed.
    socket =
      if socket.assigns[:flash_fresh],
        do: assign(socket, flash_fresh: false),
        else: assign(socket, game_flash: nil)

    socket =
      assign(socket,
        screen: screen,
        picked: nil,
        page_title: Screens.page_title(screen, filter_race(socket))
      )

    if connected?(socket) and Player.started?(socket.assigns.player) do
      apply_action(socket, &Actions.set_screen(&1, screen))
    else
      socket
    end
    |> load_screen_data(screen)
  end

  defp load_screen_data(socket, "highscores"), do: assign(socket, boards: Board.current())

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

  def handle_event("restart", _params, socket) do
    session = socket.assigns.session_id

    if Actions.may_restart?(socket.assigns.player) do
      player = Characters.archive(session)
      # Archiving stops the process this tab attached to, so the run it starts has no viewers and
      # reports itself unwatched. This tab attaches to the new one here rather than off its own
      # broadcast, which it will not have handled before the assign below moves the id past it.
      Characters.attach(session)

      {:noreply,
       socket
       |> assign(
         player: player,
         view: Snapshot.build(player),
         character_id: Characters.character_id(session)
       )
       |> go("start")}
    else
      {:noreply, socket}
    end
  end

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
  def handle_info({:character_updated, player, character_id}, socket) do
    # A push can invalidate where this tab is standing: another tab restarts the character, or the
    # server kills it. Re-pin against the new player, and treat a reset as a trip back to Game
    # Start rather than leaving this tab on a screen its character no longer qualifies for.
    reset? = Player.started?(socket.assigns.player) and not Player.started?(player)

    # Archiving stops the process this tab attached to, and the run it starts has no viewers, so it
    # reports itself unwatched until every tab attaches again. The id moves only here, so an
    # ordinary tick pays nothing for the check.
    if character_id != socket.assigns.character_id,
      do: Characters.attach(socket.assigns.session_id)

    socket =
      assign(socket, player: player, view: Snapshot.build(player), character_id: character_id)

    target = Access.pin_screen(if(reset?, do: "start", else: socket.assigns.screen), player)

    {:noreply, if(target == socket.assigns.screen, do: socket, else: leave(socket, target))}
  end

  # Both are taken only on the screen that draws them. A realm at play moves a counter and a ranking
  # every few hundred milliseconds, and assigning either anywhere else re-renders every connected
  # player for a figure they cannot see. Arriving reads it afresh, in `load_screen_data/2`.
  def handle_info({:board, boards}, %{assigns: %{screen: "highscores"}} = socket),
    do: {:noreply, assign(socket, boards: boards)}

  def handle_info({:board, _boards}, socket), do: {:noreply, socket}

  def handle_info({:statistics, stats}, %{assigns: %{screen: "statistics"}} = socket),
    do: {:noreply, assign(socket, statistics: stats)}

  def handle_info({:statistics, _stats}, socket), do: {:noreply, socket}

  # Rebuilt from the player the push carried, so nothing is read back bar the fights the chronicle
  # has yet to see. `id` twice in the head guards that this tab watches this record; the map pattern
  # guards the other way, since a record never found has nothing to compare against.
  def handle_info(
        {:record_updated, player, id},
        %{assigns: %{watching: id, record_view: %{counters: _} = shown}} = socket
      ) do
    view = Snapshot.build(player)
    socket = assign(socket, record_view: view)

    {:noreply, if(fought?(view, shown), do: append_chronicle(socket, id), else: socket)}
  end

  def handle_info({:record_updated, _player, _id}, socket), do: {:noreply, socket}

  # Two signals, because neither alone is enough: the tally does not count the fight that killed
  # them, and a narrative can repeat where the numbers do not.
  defp fought?(view, shown) do
    view.counters.total_battles != shown.counters.total_battles or
      view.last_battle != shown.last_battle
  end

  # Appended, never re-read: a run's chronicle only ever grows, so asking for the whole of it on
  # every blow re-reads the entire history of a long run to add one line to it.
  defp append_chronicle(socket, id) do
    log = socket.assigns.record_log

    assign(socket, record_log: log ++ BattleLog.history(id, length(log)))
  end

  # ------------------------------------------------------------------ plumbing

  # Runs an action in the character's process and folds the result into the view. A failure lands on
  # the error screen rather than remounting; `catch` is for the process exiting, which is not a raise.
  defp apply_action(socket, fun) do
    {result, player} = Characters.mutate(socket.assigns.session_id, fun)

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
    detail = if Version.debug_build?(), do: detail

    socket |> assign(error_detail: detail) |> go("error")
  end

  defp absorb(socket, {:error, _code, message}),
    do: assign(socket, notice: message, game_flash: nil)

  defp absorb(socket, {:ok, nil}), do: assign(socket, notice: nil)

  defp absorb(socket, {:ok, %{text: _} = flash}),
    do: socket |> assign(notice: nil, game_flash: flash) |> play(flash[:sound])

  defp absorb(socket, {:ok, result}) do
    socket
    |> assign(notice: nil, game_flash: Map.get(result, :flash))
    |> play(Map.get(result, :sound))
  end

  defp play(socket, nil), do: socket
  defp play(socket, sound), do: push_event(socket, "play-sound", %{name: sound})

  # An action moved you, so its flash comes along — creating a character lands on Town with its
  # welcome, dying lands on the death screen with its reason.
  defp go(socket, screen) do
    socket
    |> assign(flash_fresh: true)
    |> push_patch(to: Paths.for_screen(screen))
  end

  # The PLAYER moved themselves, so nothing comes along. A link or the banner reaches
  # handle_params with no flag at all and is dropped there; these events need saying so, because
  # a flash from an earlier action is still sitting in the assigns.
  defp leave(socket, screen), do: socket |> assign(game_flash: nil) |> go(screen)

  # Wording is chosen from the CURRENT ambush state rather than from the limiter, which carries
  # only one generic message. Flavour, not security.
  defp throttle(socket, limiter) do
    case RateLimit.check(socket.assigns.session_id, limiter) do
      :ok ->
        {:ok, socket}

      {:error, retry_after_ms} ->
        seconds = max(1, ceil(retry_after_ms / 1000))

        message =
          if socket.assigns.view[:ambushed] && !socket.assigns.view[:dead] do
            "You are in the middle of an ambush and moving too fast, try again in #{seconds}s."
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
    <Layouts.app
      flash={@flash}
      title={Screens.title(@screen, filter_race(assigns))}
      view={@view}
      screen={@screen}
      character_id={@character_id}
    >
      <Controls.notice :if={@notice} message={@notice} />
      <Controls.flash_alert :if={@game_flash} flash={@game_flash} />
      <Controls.low_health
        :if={Screens.low_health_alert?(@view, @screen)}
        ambushed={@view.ambushed}
        ambush_line={@view.ambush_low_health}
      />

      <Screens.screen
        screen={@screen}
        view={@view}
        catalog={@catalog}
        boards={@boards}
        character_id={@character_id}
        record={@record}
        record_view={@record_view}
        record_log={@record_log}
        from={@from}
        statistics={@statistics}
        race_filter={@race_filter}
        detail={@error_detail}
        picked={@picked}
      />
    </Layouts.app>
    """
  end
end
