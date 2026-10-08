defmodule MiniLineageWeb.GameLive do
  @moduledoc """
  The single game LiveView. It holds no authoritative state: the character's process does, so a
  disconnect, a refresh or a second tab all read the same live character.

  Every navigation passes through `Access.pin_screen/2` in `handle_params/3`, so an in-app link, a
  typed URL and the Back button obey one set of rules.
  """
  use MiniLineageWeb, :live_view

  alias MiniLineage.{CharacterLog, Board, Characters}
  require Logger

  alias MiniLineage.Game.{Access, Actions, Format, Player, RateLimit, Snapshot, Version}
  alias MiniLineage.Game.Statistics.Collector
  alias MiniLineageWeb.{Controls, Paths, Screens}

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
    end

    player = Characters.snapshot(id)

    {:ok,
     socket
     |> assign(
       session_id: id,
       # Public, and the only id that may be rendered.
       character_id: Characters.character_id(id),
       player: player,
       view: Snapshot.build(player),
       catalog: Snapshot.catalog(),
       screen: "start",
       title: nil,
       race_filter: nil,
       game_flash: nil,
       boards: %{},
       following: nil,
       record: nil,
       record_view: nil,
       watching: nil,
       record_log: [],
       record_log_cursor: 0,
       record_log_older: false,
       record_log_present: true,
       from: nil,
       statistics: nil,
       key_buffer: [],
       error_detail: nil,
       picked: nil,
       flash_fresh: false,
       sorts: kept_sorts(get_connect_params(socket))
     )}
  end

  # Kept sorts arrive with the socket, so the first connected render has them. Checked against each
  # table, since storage is the reader's to edit.
  defp kept_sorts(%{"tables" => kept}) when is_map(kept) do
    Enum.reduce(kept, %{}, fn {table, value}, sorts ->
      case Controls.decode_sort(value, Screens.sorts(table)) do
        nil -> sorts
        sort -> Map.put(sorts, table, sort)
      end
    end)
  end

  defp kept_sorts(_params), do: %{}

  # ------------------------------------------------------------- navigation

  @impl true
  def handle_params(params, _uri, socket) do
    requested = requested_screen(socket.assigns.live_action, socket.assigns.player)
    pinned = Access.pin_screen(requested, socket.assigns.player)

    if pinned != requested do
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
  # URL of its own.
  defp requested_screen(:root, player) do
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

  defp filter_race(%{assigns: assigns}), do: filter_race(assigns)

  defp filter_race(%{race_filter: id, catalog: catalog}),
    do: Enum.find(catalog.races, &(&1.id == id))

  # Read from the run's process while one is up: where it stands, its auras and its health are
  # buffered, so the row can be behind.
  defp assign_record(socket, %{"id" => id}) do
    # A record nobody can find is a 404, the same as a road the game never had.
    {player, entry} =
      Map.pop(Board.entry(id, player: true) || raise(MiniLineageWeb.NotFoundError), :player)

    view =
      if entry.id == socket.assigns.character_id,
        do: socket.assigns.view,
        else: Snapshot.build(Characters.running(entry.id) || player)

    {log, older?} = CharacterLog.page(entry.id)

    socket
    |> watch_record(entry.id)
    |> assign(
      record: entry,
      record_view: view,
      record_log: log,
      record_log_cursor: cursor(log),
      record_log_older: older?,
      # A record opens on its newest entry, so its reader is there until the hook says otherwise.
      record_log_present: true
    )
  end

  defp assign_record(socket, _params), do: socket |> watch_record(nil) |> clear_record()

  # The newest entry held, so what arrives next is asked for by id: a capped first page's length
  # says nothing about where the run got to.
  defp cursor([]), do: 0
  defp cursor([newest | _]), do: newest.id

  defp top_number([]), do: 0
  defp top_number([newest | _]), do: newest.number

  defp clear_record(socket) do
    assign(socket,
      record: nil,
      record_view: nil,
      record_log: [],
      record_log_cursor: 0,
      record_log_older: false,
      record_log_present: true
    )
  end

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

  defp assign_from(socket, %{"from" => from}), do: assign(socket, from: from)
  defp assign_from(socket, _params), do: assign(socket, from: nil)

  # Reporting the screen is what drives the combat/resting auras, so it must happen on arrival.
  defp enter(socket, screen) do
    # A flash survives exactly one arrival, so an action that flashes and moves you does not clear
    # its own message.
    socket =
      if socket.assigns[:flash_fresh],
        do: assign(socket, flash_fresh: false),
        else: assign(socket, game_flash: nil)

    socket =
      assign(socket,
        screen: screen,
        picked: nil,
        page_title: Screens.page_title(screen, filter_race(socket)),
        # Assigned, not computed in the template: an expression over `assigns` is re-sent on
        # every render.
        title: Screens.title(screen, filter_race(socket)),
        # A fault belongs to the error screen it brought you to, not to the next visit to it.
        error_detail: if(screen == "error", do: socket.assigns.error_detail)
      )

    # Not for the dead, whom no aura or pin reads it for; nor on the error screen, whose cause may be
    # the very process this would call.
    if connected?(socket) and Player.started?(socket.assigns.player) and
         not socket.assigns.player.dead and screen != "error" do
      apply_action(socket, &Actions.set_screen(&1, screen), nil, quiet: true)
    else
      socket
    end
    |> load_screen_data(screen)
  end

  # Followed only while it is the screen, and subscribed BEFORE it is read, so a refresh between
  # arrives as a push. Already followed, the pushes have kept every filter current.
  defp load_screen_data(%{assigns: %{following: :board}} = socket, "highscores"), do: socket

  defp load_screen_data(socket, "highscores") do
    socket = follow(socket, :board)
    assign(socket, boards: Board.current(), statistics: nil)
  end

  defp load_screen_data(socket, "statistics") do
    socket = follow(socket, :statistics)
    assign(socket, statistics: Collector.read_all(), boards: %{})
  end

  defp load_screen_data(socket, _screen),
    do: socket |> follow(nil) |> assign(boards: %{}, statistics: nil)

  defp follow(%{assigns: %{following: topic}} = socket, topic), do: socket

  defp follow(socket, topic) do
    if connected?(socket) do
      unfollow(socket.assigns.following)
      if topic == :board, do: Board.subscribe()
      if topic == :statistics, do: Collector.subscribe()
    end

    assign(socket, following: topic)
  end

  defp unfollow(:board), do: Board.unsubscribe()
  defp unfollow(:statistics), do: Collector.unsubscribe()
  defp unfollow(nil), do: :ok

  # ----------------------------------------------------------------- events

  @impl true
  # An explicit click into Battle IS a user action, so it fights immediately — never on load.
  def handle_event("navigate", %{"to" => "battle"}, socket),
    do: {:noreply, socket |> assign(game_flash: nil) |> fight("battle")}

  def handle_event("navigate", %{"to" => screen}, socket) do
    {:noreply, leave(socket, screen)}
  end

  def handle_event("start", %{"name" => name, "race_id" => race_id} = params, socket) do
    archetype = params["archetype"]
    {:noreply, apply_action(socket, &Actions.start(&1, race_id, archetype, name), "home")}
  end

  def handle_event("fight", _params, socket), do: {:noreply, fight(socket, nil)}

  def handle_event("purchase", %{"item_id" => ""}, socket), do: {:noreply, leave(socket, "home")}

  def handle_event("purchase", %{"item_id" => item_id, "type" => type}, socket) do
    case throttle(socket, :shop) do
      {:ok, socket} ->
        # Back on "🚪 Home Town" once the shop has answered, a refusal included.
        socket = apply_action(socket, &Actions.purchase(&1, type, item_id))

        {:noreply, assign(socket, picked: nil)}

      {:limited, socket} ->
        {:noreply, socket}
    end
  end

  def handle_event("transfer", %{"class_id" => ""}, socket), do: {:noreply, leave(socket, "home")}

  def handle_event("transfer", %{"class_id" => class_id}, socket) do
    socket = apply_action(socket, &Actions.transfer(&1, class_id))
    {:noreply, assign(socket, picked: nil)}
  end

  def handle_event("draw_dye", %{"dye_id" => ""}, socket), do: {:noreply, leave(socket, "home")}

  def handle_event("draw_dye", %{"dye_id" => dye_id}, socket) do
    case throttle(socket, :shop) do
      {:ok, socket} ->
        {:noreply, assign(apply_action(socket, &Actions.draw_dye(&1, dye_id)), picked: nil)}

      {:limited, socket} ->
        {:noreply, socket}
    end
  end

  def handle_event("remove_dye", %{"slot" => slot}, socket) do
    case throttle(socket, :shop) do
      {:ok, socket} -> {:noreply, apply_action(socket, &Actions.remove_dye(&1, slot))}
      {:limited, socket} -> {:noreply, socket}
    end
  end

  def handle_event("suicide", %{"confirm" => "yes"}, socket),
    do: {:noreply, apply_action(socket, &Actions.suicide/1, "death")}

  def handle_event("suicide", _params, socket), do: {:noreply, leave(socket, "home")}

  def handle_event("restart", _params, socket) do
    session = socket.assigns.session_id

    if Actions.may_restart?(socket.assigns.player) do
      player = Characters.archive(session)
      # Archiving stops the process this tab attached to. Attach to the new one here, not off the
      # broadcast, which the assign below would move the id past before it is handled.
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

  # The Konami buffer lives here rather than in the character, so nothing about the sequence is
  # persisted and a second tab cannot half-complete it.
  def handle_event("key", %{"key" => key}, socket) do
    sequence = MiniLineage.Game.Constants.konami_sequence()
    buffer = Enum.take(socket.assigns.key_buffer ++ [key], -length(sequence))

    cond do
      # The page relays only for a run the sequence can touch; this is for a client that does not.
      not Access.konami?(socket.assigns.view) ->
        {:noreply, socket}

      buffer == sequence ->
        {:noreply, socket |> assign(key_buffer: []) |> apply_action(&Actions.cheat/1)}

      true ->
        {:noreply, assign(socket, key_buffer: buffer)}
    end
  end

  # The reader scrolled near the oldest entry held. Asked by that entry, so a second ask in flight
  # reads the same page and is dropped rather than put on the end twice.
  def handle_event("older_chronicle", %{"before" => before}, socket) do
    {:reply, %{}, older_chronicle(socket, before)}
  end

  # Sent only as the reader leaves the newest entry or comes back to it, never per arrival.
  def handle_event("chronicle_at_present", %{"at" => at}, socket) when is_boolean(at) do
    {:noreply, assign(socket, record_log_present: at)}
  end

  # A sort orders rows the socket already holds, so it reads nothing and gates nothing: it is
  # this tab's view of a table, not something a run does.
  def handle_event("sort", %{"table" => table, "key" => key}, socket) do
    case Screens.sorts(table) do
      %{^key => first} ->
        sort = Controls.next_sort(socket.assigns.sorts[table], key, first)
        {:noreply, put_sort(socket, table, sort)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("reset_sort", %{"table" => table}, socket),
    do: {:noreply, put_sort(socket, table, nil)}

  # ----------------------------------------------------------------- pushes

  @impl true
  # The echo of this tab's own action, which `apply_action/4` has already folded in.
  def handle_info(
        {:character_updated, player, character_id},
        %{assigns: %{player: player, character_id: character_id}} = socket
      ),
      do: {:noreply, socket}

  def handle_info({:character_updated, player, character_id}, socket) do
    # Another tab restarting the character, or the server killing it, can invalidate where this
    # tab stands: re-pin, and treat a reset as a trip back to Game Start.
    reset? = Player.started?(socket.assigns.player) and not Player.started?(player)

    # A new run has no viewers until every tab attaches to it again.
    if character_id != socket.assigns.character_id,
      do: Characters.attach(socket.assigns.session_id)

    socket =
      assign(socket, player: player, view: Snapshot.build(player), character_id: character_id)

    target = Access.pin_screen(if(reset?, do: "start", else: socket.assigns.screen), player)

    {:noreply, if(target == socket.assigns.screen, do: socket, else: leave(socket, target))}
  end

  # Followed only on the screen that draws them; one already queued when the reader left is dropped.
  def handle_info({:board, boards}, %{assigns: %{screen: "highscores"}} = socket),
    do: {:noreply, assign(socket, boards: boards)}

  def handle_info({:board, _boards}, socket), do: {:noreply, socket}

  def handle_info({:statistics, stats}, %{assigns: %{screen: "statistics"}} = socket),
    do: {:noreply, assign(socket, statistics: stats)}

  def handle_info({:statistics, _stats}, socket), do: {:noreply, socket}

  # Rebuilt from the pushed player; only entries the chronicle has yet to see are read back. `id`
  # twice guards that this tab watches this record, and the push says whether a row was written.
  def handle_info(
        {:record_updated, player, id, wrote?},
        %{assigns: %{watching: id}} = socket
      ) do
    # Your own record is the view the character topic just built; only a stranger's is built here.
    view =
      if id == socket.assigns.character_id, do: socket.assigns.view, else: Snapshot.build(player)

    socket = assign(socket, record_view: view)

    {:noreply, if(wrote?, do: append_chronicle(socket, id), else: socket)}
  end

  def handle_info({:record_updated, _player, _id, _wrote?}, socket), do: {:noreply, socket}

  # Its row changed, not its state, so the ENTRY is read again, which no push carries. Once in a
  # run's life.
  def handle_info({:record_retired, id}, %{assigns: %{watching: id}} = socket),
    do: {:noreply, assign(socket, record: Board.entry(id))}

  def handle_info({:record_retired, _id}, socket), do: {:noreply, socket}

  # The warning that set the timer, and only that one: a newer warning has a timer of its own.
  def handle_info({:flash_expired, ref}, %{assigns: %{game_flash: %{expires: ref}}} = socket),
    do: {:noreply, assign(socket, game_flash: nil)}

  def handle_info({:flash_expired, _ref}, socket), do: {:noreply, socket}

  # A chronicle only grows, so only what is new is read. At the present the oldest goes as the
  # newest lands, never under a page nor over what the reader had; elsewhere it grows, since they
  # may be reading what would go.
  defp append_chronicle(socket, id) do
    %{record_log: held, record_log_cursor: cursor} = socket.assigns
    added = CharacterLog.since(id, cursor, top_number(held))

    case added do
      [] ->
        socket

      _ ->
        [newest | _] = added
        kept = if socket.assigns.record_log_present, do: max(CharacterLog.window(), length(held))
        log = if kept, do: Enum.take(added ++ held, kept), else: added ++ held

        # The road above the panel is dated by the same entry, so it moves with the chronicle.
        assign(socket,
          record: %{socket.assigns.record | last_seen_at: newest.at},
          record_log: log,
          record_log_cursor: newest.id,
          record_log_older: socket.assigns.record_log_older or length(log) < length(added ++ held)
        )
    end
  end

  defp older_chronicle(
         %{assigns: %{record: %{id: id}, record_log: [_ | _] = log}} = socket,
         before
       ) do
    if List.last(log).id == before do
      {older, more?} = CharacterLog.page(id, before)
      assign(socket, record_log: log ++ older, record_log_older: more?)
    else
      socket
    end
  end

  defp older_chronicle(socket, _before), do: socket

  # ------------------------------------------------------------------ plumbing

  defp put_sort(socket, table, nil),
    do: assign(socket, sorts: Map.delete(socket.assigns.sorts, table))

  defp put_sort(socket, table, sort),
    do: assign(socket, sorts: Map.put(socket.assigns.sorts, table, sort))

  # A socket holds one patch, so where an action leaves them is decided here, once: error, death,
  # else `to`. `catch` is for the process exiting. `quiet` is for what the player did not do,
  # arriving somewhere, which leaves their flash alone.
  defp apply_action(socket, fun, to \\ nil, opts \\ []) do
    {result, player} = Characters.mutate(socket.assigns.session_id, fun)
    to = if player.dead and not socket.assigns.player.dead, do: "death", else: to

    socket
    |> assign(player: player, view: Snapshot.build(player))
    |> then(&if(opts[:quiet], do: &1, else: absorb(&1, result)))
    |> then(&if(to, do: go(&1, to), else: &1))
  rescue
    error ->
      Logger.error(Exception.format(:error, error, __STACKTRACE__))
      fail(socket, Exception.message(error))
  catch
    :exit, reason ->
      Logger.error("character process exited: #{inspect(reason)}")
      fail(socket, "the character process exited: #{inspect(reason)}")
  end

  # Withheld outside a debug build: a player is never handed a stack.
  defp fail(socket, detail) do
    detail = if Version.debug_build?(), do: detail

    socket |> assign(error_detail: detail) |> go("error")
  end

  defp absorb(socket, {:error, _code, message}), do: refuse(socket, message)

  defp absorb(socket, {:ok, nil}), do: socket

  defp absorb(socket, {:ok, %{text: _} = flash}),
    do: socket |> assign(game_flash: flash) |> play(flash[:sound])

  defp absorb(socket, {:ok, result}) do
    socket
    |> assign(game_flash: Map.get(result, :flash))
    |> play(Map.get(result, :sound))
  end

  # A refusal is a flash like any other, so it too belongs to the screen it is raised on.
  defp refuse(socket, message), do: assign(socket, game_flash: %{text: message, type: :danger})

  defp play(socket, nil), do: socket
  defp play(socket, sound), do: push_event(socket, "play-sound", %{name: sound})

  # Travelling to the Battleground fights on arrival; a throttled fight still arrives.
  defp fight(socket, to) do
    case throttle(socket, :battle) do
      {:ok, socket} -> apply_action(socket, &Actions.fight/1, to)
      {:limited, socket} -> if(to, do: go(socket, to), else: socket)
    end
  end

  # An action moved you, so its flash comes along — creating a character lands on Town with its
  # welcome, dying lands on the death screen with its reason.
  defp go(socket, screen) do
    socket
    |> assign(flash_fresh: true)
    |> push_patch(to: Paths.for_screen(screen))
  end

  # The PLAYER moved themselves, so nothing comes along. A link is dropped in handle_params with no
  # flag; these events must say so, since an earlier flash is still in the assigns.
  defp leave(socket, screen), do: socket |> assign(game_flash: nil) |> go(screen)

  # The warning counts down in the page and is taken down by the server once the window reopens,
  # since a patch would put back anything the browser removed.
  defp throttle(socket, limiter) do
    case RateLimit.check(socket.assigns.session_id, limiter) do
      :ok ->
        {:ok, socket}

      {:error, retry_after_ms} ->
        ref = make_ref()
        Process.send_after(self(), {:flash_expired, ref}, retry_after_ms)
        text = throttled(limiter, socket.assigns.view, countdown(retry_after_ms))

        {:limited, assign(socket, game_flash: %{text: text, type: :danger, expires: ref})}
    end
  end

  # The shape `EffectTimers` repaints, as the record's Blessings & Afflictions say a time.
  defp countdown(ms) do
    label = ~s(<span data-timer="long">#{Format.remaining(ms)}</span>)
    ~s(<span data-remaining-ms="#{ms}">#{label}</span>)
  end

  # What happened, closed by its emoji rather than a stop, then what to do about it: a line each,
  # so the wait is never stranded. Only the ambush waits out the pause, so only it is told apart.
  defp throttled(:battle, %{ambushed: true, dead: false}, wait),
    do:
      "Your arm cannot swing that fast 💢<br />" <>
        "The ambush waits, so strike again in&nbsp;#{wait}."

  defp throttled(:battle, _view, wait),
    do: "You are out of breath 😮‍💨<br />Rest a moment and seek another fight in&nbsp;#{wait}."

  defp throttled(:shop, _view, wait),
    do:
      "The shopkeeper cannot keep up with you ⏳<br />" <>
        "Give them a moment and try again in&nbsp;#{wait}."

  # ------------------------------------------------------------------ render

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      title={@title}
      view={@view}
      screen={@screen}
      character_id={@character_id}
    >
      <Controls.flash_alert :if={@game_flash} flash={@game_flash} />
      <Controls.low_health
        :if={Screens.low_health_alert?(@view, @screen)}
        ambushed={@view.ambushed}
        ambush_line={@view.ambush_low_health}
      />

      <:aside :if={Screens.aside?(@screen, @record)}>
        <Screens.aside
          screen={@screen}
          record={@record}
          record_log={@record_log}
          record_log_older={@record_log_older}
          character_id={@character_id}
        />
      </:aside>

      <Screens.screen
        screen={@screen}
        view={@view}
        catalog={@catalog}
        boards={@boards}
        character_id={@character_id}
        record={@record}
        record_view={@record_view}
        from={@from}
        statistics={@statistics}
        race_filter={@race_filter}
        detail={@error_detail}
        picked={@picked}
        sorts={@sorts}
      />
    </Layouts.app>
    """
  end
end
