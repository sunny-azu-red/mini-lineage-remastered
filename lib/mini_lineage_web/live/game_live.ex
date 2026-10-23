defmodule MiniLineageWeb.GameLive do
  @moduledoc """
  The single game LiveView. It holds no authoritative state: the character's process does, so a
  disconnect, a refresh or a second tab all read the same live character.

  Every navigation passes through `Access.pin_screen/2` in `handle_params/3`, so an in-app link, a
  typed URL and the Back button obey one set of rules.
  """
  use MiniLineageWeb, :live_view

  alias MiniLineage.{Board, Characters}
  require Logger

  alias MiniLineage.Game.{Access, Actions, Clock, Math, Narratives, Player, Rules, Snapshot}
  alias MiniLineage.Game.Version
  alias MiniLineageWeb.{Controls, Kept, Paths, Screens}

  # Debug builds only: a name already written on game start, so trying another race is one click.
  @dev_names ~w(Aerin Baelor Cadmus Darion Elowen Fenris Galen Hadrian Isolde Jorah Kaelith Lucan
                Morwen Nerys Orin Perrin Quill Rowan Sorcha Talia Ulric Vesper Wren Ysolde)

  # What every page shares, whoever it belongs to: today, a debug build forcing the hour.
  @world "world"

  # Debug builds only: what is typed outside a text field, and what each sequence does.
  @dev_sequences [
    {~w(a d e n a), :adena},
    {~w(s p), :sp},
    {~w(n i g h t), :night},
    {~w(d a y), :day},
    {~w(h a l f), :half},
    {~w(f r a i l), :frail},
    # Before `lvl`, which it ends in: the first match wins.
    {~w(m a x l v l), :max_level},
    {~w(l v l), :level},
    {~w(ctrl+q), :quit}
  ]
  @dev_longest @dev_sequences |> Enum.map(fn {keys, _} -> length(keys) end) |> Enum.max()

  @impl true
  def mount(_params, %{"session_id" => id} = session, socket) when is_binary(id) do
    kept = Kept.read(connect_kept(socket) || session["kept"])

    if connected?(socket) do
      Characters.attach(id)
      Characters.subscribe(id)
      Phoenix.PubSub.subscribe(MiniLineage.PubSub, @world)
      await_minute()
    end

    player = Characters.snapshot(id)

    {:ok,
     assign(socket,
       session_id: id,
       player: player,
       view: Snapshot.build(player),
       catalog: Snapshot.catalog(),
       screen: "start",
       town: nil,
       back: nil,
       boards: %{},
       fight: nil,
       next_move: nil,
       following_board: false,
       character_id: nil,
       picked: nil,
       picks: %{},
       sorts: kept.sorts,
       folds: kept.folds,
       sound: kept.sound,
       dev_name: nil,
       keys: [],
       game_flash: nil,
       flash_fresh: false,
       error_detail: nil,
       debug: Version.debug_build?(),
       now: Clock.now(),
       hour_timer: nil
     )
     |> then(&if(connected?(&1), do: await_dusk_or_dawn(&1), else: &1))}
  end

  # A cookie the plug never saw — a tab left open across a deploy. A LiveView cannot issue one, so
  # bounce through a real request. The plug always sets one, so this cannot come round twice.
  def mount(_params, _session, socket), do: {:ok, redirect(socket, to: ~p"/")}

  # The cookie as the browser holds it now, which beats the page's copy: a reconnect after a
  # restart, or after another tab changed something, rejoins with the token the page was served.
  defp connect_kept(socket) do
    case connected?(socket) && get_connect_params(socket) do
      %{"kept" => kept} when is_binary(kept) -> kept
      _ -> nil
    end
  end

  # ------------------------------------------------------------- navigation

  @impl true
  def handle_params(_params, uri, socket) do
    requested = requested_place(socket.assigns.live_action, uri, socket.assigns.player)
    pinned = Access.pin_screen(requested, socket.assigns.player)
    to = Paths.for_screen(pinned)

    # Compared by address, so '/' moves a character to the town it stands in: the URL is where you are.
    if to != URI.parse(uri).path,
      do: {:noreply, push_patch(socket, to: to, replace: true)},
      else: {:noreply, enter(socket, pinned)}
  end

  # '/' is wherever the browser's own state puts it.
  defp requested_place(:root, _uri, player),
    do: if(Player.started?(player), do: {"town", player.location}, else: {"start", nil})

  defp requested_place(action, uri, _player)
       when action in [:town, :gatekeeper, :hunt, :trader, :guild],
       do: {Atom.to_string(action), Paths.town_of(uri)}

  defp requested_place(:highscores, uri, _player), do: {"highscores", Paths.lineage_of(uri)}

  defp requested_place(:trader_page, uri, _player),
    do:
      {"trader-" <> (uri |> URI.parse() |> Map.fetch!(:path) |> Path.basename()),
       Paths.town_of(uri)}

  defp requested_place(action, _uri, _player), do: {Atom.to_string(action), nil}

  defp enter(socket, {screen, town}) do
    # A flash survives exactly one arrival, so an action that flashes and moves you does not clear
    # its own message.
    socket =
      if socket.assigns.flash_fresh,
        do: assign(socket, flash_fresh: false),
        else: assign(socket, game_flash: nil)

    socket = engage_if(socket, screen == "hunt")

    socket
    |> follow_board(screen == "highscores")
    |> assign(
      screen: screen,
      town: town,
      back: back(socket.assigns, screen),
      # A choice belongs to the screen it was made on.
      picked: nil,
      picks: %{},
      # Rules §20: a ground draws the last fight fought there, so a reload or a return finds it.
      fight: if(screen == "hunt", do: last_fight(socket, town)),
      next_move: nil,
      dev_name:
        if(screen == "start" and socket.assigns.debug, do: Math.random_element(@dev_names)),
      # A fault belongs to the error screen it brought you to, not to the next visit to it.
      error_detail: if(screen == "error", do: socket.assigns.error_detail)
    )
    # Rebuilt on every arrival, so an effect drawn afresh counts down from the time left now and
    # not from when the view was last built.
    |> put_view(socket.assigns.player)
  end

  # The inventory closes onto the page its sidebar link was clicked on, or the town after a reload.
  defp back(%{screen: "inventory", back: back}, "inventory"), do: back

  defp back(%{screen: from, town: town, player: player}, "inventory"),
    do: if(Access.sidebar?(from), do: {from, town}, else: here(player))

  defp back(_assigns, _screen), do: nil

  # Rules §20: the ground is combat, fought on or not, and leaving it by any road (the banner, a
  # link) disengages as retreating does.
  defp engage_if(%{assigns: %{player: %{combat: "engaged"}}} = socket, true), do: socket
  defp engage_if(socket, true), do: combat(socket, &Player.engage/1)

  defp engage_if(%{assigns: %{player: %{combat: "engaged"}}} = socket, false),
    do: combat(socket, &Player.disengage/1)

  defp engage_if(socket, false), do: socket

  defp combat(socket, change) do
    {_, player} = Characters.mutate(socket.assigns.session_id, &{change.(&1), :ok})
    assign(socket, player: player)
  end

  # Followed only while the Halls are the screen, and subscribed BEFORE they are read, so a refresh
  # in between arrives as a push. Already followed, the pushes have kept every filter current.
  defp follow_board(%{assigns: %{following_board: true}} = socket, true), do: socket

  defp follow_board(socket, true) do
    Board.subscribe()
    id = if socket.assigns.view.started, do: Characters.character_id(socket.assigns.session_id)

    assign(socket, following_board: true, boards: Board.current(), character_id: id)
  end

  defp follow_board(%{assigns: %{following_board: true}} = socket, false) do
    Board.unsubscribe()
    assign(socket, following_board: false, boards: %{})
  end

  defp follow_board(socket, false), do: socket

  # ----------------------------------------------------------------- events

  @impl true
  def handle_event("start", %{"name" => name, "race_id" => race_id} = params, socket) do
    path = params["path"]
    {:noreply, apply_action(socket, &Actions.start(&1, race_id, path, name), &here/1)}
  end

  # A choice relabels its button before it is acted on.
  def handle_event("pick", %{"_target" => [field]} = params, socket),
    do:
      {:noreply,
       assign(socket,
         picked: params[field],
         picks: Map.put(socket.assigns.picks, field, params[field])
       )}

  # Somewhere inside the town, which is where you stand already: a patch, never a write.
  def handle_event("navigate", %{"place" => "gatekeeper"}, socket),
    do: {:noreply, walk(socket, {"gatekeeper", socket.assigns.town})}

  @inner ~w(trader guild) ++ Enum.map(Paths.trader_pages(), &("trader-" <> &1))

  # Rules §20: going out to the ground meets nothing until the player looks for a fight.
  def handle_event("navigate", %{"place" => place}, socket) when place in ["hunt" | @inner],
    do: {:noreply, walk(socket, {place, socket.assigns.town})}

  # The empty choice of a menu inside a town goes back to the town.
  def handle_event("navigate", %{"place" => ""}, socket),
    do: {:noreply, walk(socket, {"town", socket.assigns.player.location})}

  def handle_event("navigate", _params, socket), do: {:noreply, socket}

  # Rules §23 and §24: what a character carries, bought, sold, equipped and unequipped where it stands.
  # A trader's page: its empty choice goes back to the trader's menu.
  def handle_event("buy", %{"item" => ""}, socket),
    do: {:noreply, walk(socket, {"trader", socket.assigns.town})}

  # A potion (rules §26) comes as "name|count", bought by the lot.
  def handle_event("buy", %{"item" => choice}, socket) do
    case String.split(choice, "|", parts: 2) do
      [name, count] ->
        case Integer.parse(count) do
          {n, ""} -> {:noreply, apply_action(socket, &Actions.buy(&1, name, n), nil)}
          _ -> {:noreply, socket}
        end

      [name] ->
        {:noreply, apply_action(socket, &Actions.buy(&1, name), nil)}
    end
  end

  def handle_event("sell", %{"item" => ""}, socket),
    do: {:noreply, walk(socket, {"trader", socket.assigns.town})}

  def handle_event("sell", %{"item" => id}, socket),
    do: {:noreply, apply_action(socket, &Actions.sell(&1, id), nil)}

  # The inventory's one choice, "<verb>:<id>"; its empty choice closes it, as the sidebar's link does.
  def handle_event("inventory", %{"item" => ""}, socket),
    do: {:noreply, walk(socket, socket.assigns.back || here(socket.assigns.player))}

  def handle_event("inventory", %{"item" => choice}, socket) do
    action =
      case String.split(choice, ":", parts: 2) do
        ["equip", id] -> &Actions.equip(&1, id)
        ["unequip", id] -> &Actions.unequip(&1, id)
        ["drink", id] -> &Actions.drink(&1, id)
        ["destroy", id] -> &Actions.destroy(&1, id)
        _ -> nil
      end

    {:noreply, if(action, do: apply_action(socket, action, nil), else: socket)}
  end

  # Rules §20 and §26: an order. A slider sends the stop it was moved to, `_target` naming it
  # (`potion`, `pull` or `fight`), a switch `use:<true|false>:<skill>`, a name that may hold a
  # colon, and the footer's 🧹 Reset to Default, `reset`.
  def handle_event("order", %{"_target" => [kind]} = params, socket)
      when kind in ~w(potion pull fight) do
    action =
      with {stop, ""} when stop >= 0 <- Integer.parse(params[kind] || ""),
           share when is_integer(share) <- Enum.at(shares(kind), stop) do
        order(kind, share)
      else
        _ -> nil
      end

    {:noreply, if(action, do: apply_action(socket, action, nil), else: socket)}
  end

  def handle_event("order", %{"order" => "reset"}, socket),
    do: {:noreply, apply_action(socket, &Actions.reset_orders/1, nil)}

  def handle_event("order", %{"order" => "use:" <> order}, socket) do
    action =
      case String.split(order, ":", parts: 2) do
        [use, name] when use in ~w(true false) -> &Actions.use_skill(&1, name, use == "true")
        _ -> nil
      end

    {:noreply, if(action, do: apply_action(socket, action, nil), else: socket)}
  end

  # Rules §25: one line from the village's guild, chosen as "skill|level"; the empty choice leaves.
  def handle_event("learn", %{"lesson" => ""}, socket),
    do: {:noreply, walk(socket, {"town", socket.assigns.town})}

  def handle_event("learn", %{"lesson" => lesson}, socket) do
    with [skill, level] <- String.split(lesson, "|", parts: 2),
         {level, ""} <- Integer.parse(level) do
      {:noreply, apply_action(socket, &Actions.learn(&1, skill, level), nil)}
    else
      _ -> {:noreply, socket}
    end
  end

  # A sort orders rows the socket already holds, so it reads nothing and gates nothing; a key no
  # table offers is ignored rather than stored.
  def handle_event("sort", %{"table" => table, "key" => key}, socket) do
    if key in Screens.sortable(table).keys do
      sort = Controls.next_sort(Screens.sort_of(socket.assigns.sorts, table), key)
      {:noreply, assign(socket, sorts: Map.put(socket.assigns.sorts, table, sort))}
    else
      {:noreply, socket}
    end
  end

  # A fold is the reader's like a sort, kept so a panel drawn again on this visit opens as they
  # left it. The browser has already folded it and kept it, so this only follows.
  def handle_event("fold", %{"panel" => id, "open" => open}, socket) when is_boolean(open),
    do: {:noreply, assign(socket, folds: Kept.fold(socket.assigns.folds, id, open))}

  def handle_event("fold", _params, socket), do: {:noreply, socket}

  # Rules §20: one click, one fight, staying on the ground, where it is written on the page; one that
  # ends the run (§21) leaves it there for good.
  def handle_event("hunt", _params, socket),
    do: {:noreply, socket |> apply_action(&Actions.hunt/1, nil) |> keep_fight()}

  # Rules §21: a run that has ended begins again, at game start.
  def handle_event("restart", _params, socket),
    do: {:noreply, apply_action(socket, &Actions.restart/1, fn _ -> {"start", nil} end)}

  def handle_event("retreat", _params, socket),
    do: {:noreply, apply_action(socket, &Actions.retreat/1, &{"town", &1.location})}

  # The Gatekeeper's empty choice is the way back into town.
  def handle_event("travel", %{"to" => ""}, socket),
    do: {:noreply, walk(socket, {"town", socket.assigns.town})}

  def handle_event("travel", %{"to" => to}, socket),
    do: {:noreply, apply_action(socket, &Actions.travel(&1, to), &here/1)}

  # Debug builds only, for a character: a sequence typed anywhere but a text field. The keys are
  # kept here, never in the character, so nothing about them is persisted.
  def handle_event(
        "key",
        %{"key" => key},
        %{assigns: %{debug: true, view: %{started: true}}} = socket
      )
      when is_binary(key) do
    # Every key counts, so whatever comes between two keys of a sequence breaks it.
    key = if key =~ ~r/\A(ctrl\+)?[a-z]\z/, do: key, else: "other"
    keys = Enum.take(socket.assigns.keys ++ [key], -@dev_longest)

    case Enum.find(@dev_sequences, fn {sequence, _} -> List.ends_with?(keys, sequence) end) do
      nil -> {:noreply, assign(socket, keys: keys)}
      {_, command} -> {:noreply, socket |> assign(keys: []) |> dev(command)}
    end
  end

  def handle_event("key", _params, socket), do: {:noreply, socket}

  defp dev(socket, :adena), do: apply_action(socket, &Actions.dev_adena/1, nil)
  defp dev(socket, :sp), do: apply_action(socket, &Actions.dev_sp/1, nil)
  defp dev(socket, :half), do: apply_action(socket, &Actions.dev_half/1, nil)
  defp dev(socket, :frail), do: apply_action(socket, &Actions.dev_frail/1, nil)
  defp dev(socket, :level), do: apply_action(socket, &Actions.dev_level/1, nil)
  defp dev(socket, :max_level), do: apply_action(socket, &Actions.dev_max_level/1, nil)

  # Every page redraws, not only this one: the hour is the world's.
  defp dev(socket, time) when time in [:night, :day] do
    :ok = Clock.force(time)
    Phoenix.PubSub.broadcast(MiniLineage.PubSub, @world, :world_changed)

    text =
      "A debug build holds the world at #{time} for five minutes, whatever the hour, and then gives the hour back."

    assign(socket, game_flash: %{text: text, type: :info})
  end

  # Kept by choice, for trying every race and path from one browser: deletes the character outright.
  defp dev(socket, :quit) do
    id = socket.assigns.session_id
    Characters.forget(id)
    Characters.attach(id)
    player = Characters.snapshot(id)

    socket
    |> put_view(player)
    |> assign(game_flash: nil)
    |> go({"start", nil})
  end

  # A fight is written on the ground's page rather than in an alert, all but a new level's gold one.
  # The button then names where the hunt goes next, drawn here rather than by the character's dice,
  # which the ladder bench seeds, and never the line it already showed.
  defp keep_fight(%{assigns: %{game_flash: %{log: _} = fight, view: %{started: true}}} = socket) do
    %{view: view, screen: screen, catalog: catalog, next_move: shown} = socket.assigns
    moves = Narratives.moves(view.ground.slug) -- [shown]

    assign(socket,
      fight: fight,
      next_move: Math.random_element(moves),
      panels: Screens.panels(screen, view, catalog, fight),
      game_flash: fight[:levelled] && Map.take(fight, [:levelled])
    )
  end

  defp keep_fight(socket), do: socket

  defp last_fight(socket, town),
    do: Characters.last_fight(socket.assigns.session_id, Rules.ground_of(town).slug)

  # ----------------------------------------------------------------- pushes

  @impl true
  # The echo of this tab's own action, which `apply_action/3` has already folded in.
  def handle_info({:character_updated, player}, %{assigns: %{player: player}} = socket),
    do: {:noreply, socket}

  def handle_info({:character_updated, player}, socket) do
    socket = put_view(socket, player)
    place = {socket.assigns.screen, socket.assigns.town}
    target = Access.pin_screen(place, player)

    {:noreply, if(target == place, do: socket, else: go(socket, target))}
  end

  # A push already queued when the reader left the Halls is dropped.
  def handle_info({:board, boards}, %{assigns: %{following_board: true}} = socket),
    do: {:noreply, assign(socket, boards: boards)}

  def handle_info({:board, _boards}, socket), do: {:noreply, socket}

  # Rules §15: nightfall changes nothing the character's process stores, so nothing is pushed for it.
  # The page wakes itself at the exact moment instead, and redraws what the hour changes. A held
  # hour moves that moment to when it is given back.
  def handle_info(:world_changed, socket),
    do: {:noreply, socket |> await_dusk_or_dawn() |> put_view(socket.assigns.player)}

  def handle_info(:dusk_or_dawn, socket),
    do: {:noreply, socket |> await_dusk_or_dawn() |> put_view(socket.assigns.player)}

  # The footer's clock, which only the server draws, so the zone it names is the game's.
  def handle_info(:minute, socket) do
    await_minute()
    {:noreply, assign(socket, now: Clock.now())}
  end

  # ------------------------------------------------------------------ plumbing

  # The panels and the title follow the view, as what a page holds can change under it (a first
  # skill learned, a death). Assigned, not computed in the template: an expression over `assigns` is
  # re-sent on every render.
  defp put_view(socket, player) do
    %{screen: screen, catalog: catalog, fight: fight} = socket.assigns
    view = Snapshot.build(player)

    assign(socket,
      player: player,
      view: view,
      panels: Screens.panels(screen, view, catalog, fight),
      page_title: Screens.page_title(screen, view)
    )
  end

  # A beat past the boundary, so the redraw reads the new hour and not the last of the old one. One
  # timer, replaced rather than added to, or every force would leave another waking the page.
  defp await_dusk_or_dawn(socket) do
    if socket.assigns.hour_timer, do: Process.cancel_timer(socket.assigns.hour_timer)
    now = Clock.now()
    wait = DateTime.diff(Clock.next_change(now), now, :millisecond) + 50

    assign(socket, hour_timer: Process.send_after(self(), :dusk_or_dawn, max(wait, 50)))
  end

  defp await_minute do
    ms = Clock.now() |> DateTime.to_unix(:millisecond) |> rem(60_000)
    Process.send_after(self(), :minute, 60_000 - ms + 50)
  end

  # Rules §20 and §26: the shares an order's stops stand for, and the action setting one.
  defp shares("potion"), do: Player.potion_shares()
  defp shares(_heal), do: Player.heal_shares()

  defp order("potion", share), do: &Actions.potion_at(&1, share)
  defp order("pull", share), do: &Actions.heal_at(&1, :pull, share)
  defp order("fight", share), do: &Actions.heal_at(&1, :fight, share)

  # A refusal stays on the screen it was raised on; a success goes on to where the action leads, a
  # place worked out from the player it left, or nowhere for nil. `catch` is for the process exiting.
  # Every action, refused or not, puts the dropdowns back to their start: a pick left standing is a
  # second purchase one click away.
  defp apply_action(socket, fun, to) do
    {result, player} = Characters.mutate(socket.assigns.session_id, fun)
    socket = socket |> put_view(player) |> assign(picked: nil, picks: %{})

    case result do
      {:error, _code, message} -> assign(socket, game_flash: %{text: message, type: :danger})
      # Nothing to say (an order, which its control shows), so what was last said stands.
      {:ok, nil} -> socket
      {:ok, flash} -> socket |> assign(game_flash: flash) |> play(sound(flash)) |> arrive(to)
    end
  rescue
    error ->
      Logger.error(Exception.format(:error, error, __STACKTRACE__))
      fail(socket, Exception.message(error))
  catch
    :exit, reason ->
      Logger.error("character process exited: #{inspect(reason)}")
      fail(socket, "the character process exited: #{inspect(reason)}")
  end

  # Staying put, unless what happened moved the character's place, as another tab can.
  defp arrive(socket, nil) do
    place = {socket.assigns.screen, socket.assigns.town}
    target = Access.pin_screen(place, socket.assigns.player)

    if target == place, do: socket, else: go(socket, target)
  end

  defp arrive(socket, to), do: go(socket, to.(socket.assigns.player))

  # Rules §21: a fallen run stands on the ground it fell on, which the inventory's Return names.
  defp here(%{dead: true} = player), do: {"hunt", player.location}
  defp here(player), do: {"town", player.location}

  # A start and a death name their own; otherwise a green alert chimes and a gold one sounds the
  # level. A fight is the page's and not an alert, so a kill alone is silent.
  defp sound(%{sound: sound}), do: sound
  defp sound(%{levelled: _}), do: "level"
  defp sound(%{log: _}), do: nil
  defp sound(%{type: :success}), do: "success"
  defp sound(_), do: nil

  defp play(socket, nil), do: socket
  defp play(socket, sound), do: push_event(socket, "play-sound", %{name: sound})

  # Withheld outside a debug build: a player is never handed a stack.
  defp fail(socket, detail) do
    detail = if Version.debug_build?(), do: detail

    socket |> assign(error_detail: detail) |> go({"error", nil})
  end

  # Where an action leads, which keeps what it said for the arrival.
  defp go(socket, place),
    do: socket |> assign(flash_fresh: true) |> push_patch(to: Paths.for_screen(place))

  # A step nothing was said about, so the arrival drops the last action's flash like any other.
  defp walk(socket, place), do: push_patch(socket, to: Paths.for_screen(place))

  # ------------------------------------------------------------------ render

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      :let={panel}
      panels={@panels}
      view={@view}
      screen={@screen}
      back={@back && Paths.for_screen(@back)}
      dev_keys={@debug and @view.started}
      folds={@folds}
      sound={@sound}
      now={@now}
    >
      <Controls.flash_alert :if={@game_flash && panel == hd(@panels)} flash={@game_flash} />

      <Screens.screen
        screen={@screen}
        panel={panel}
        view={@view}
        catalog={@catalog}
        detail={@error_detail}
        picked={@picked}
        dev_name={@dev_name}
        boards={@boards}
        lineage={@town}
        character_id={@character_id}
        fight={@fight}
        next_move={@next_move}
        back={@back}
        picks={@picks}
        sorts={@sorts}
      />
    </Layouts.app>
    """
  end
end
