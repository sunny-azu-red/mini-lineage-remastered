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

  alias MiniLineage.Game.{Access, Actions, Clock, Math, Player, Snapshot, Version}
  alias MiniLineageWeb.{Controls, Paths, Screens}

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
    # Before `lvl`, which it ends in: the first match wins.
    {~w(m a x l v l), :max_level},
    {~w(l v l), :level},
    {~w(ctrl+q), :quit}
  ]
  @dev_longest @dev_sequences |> Enum.map(fn {keys, _} -> length(keys) end) |> Enum.max()

  @impl true
  def mount(_params, %{"session_id" => id}, socket) when is_binary(id) do
    if connected?(socket) do
      Characters.attach(id)
      Characters.subscribe(id)
      Phoenix.PubSub.subscribe(MiniLineage.PubSub, @world)
      await_dusk_or_dawn()
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
       boards: %{},
       fight: nil,
       following_board: false,
       character_id: nil,
       picked: nil,
       picks: %{},
       dev_name: nil,
       keys: [],
       icon: nil,
       game_flash: nil,
       flash_fresh: false,
       error_detail: nil,
       debug: Version.debug_build?()
     )}
  end

  # A cookie the plug never saw — a tab left open across a deploy. A LiveView cannot issue one, so
  # bounce through a real request. The plug always sets one, so this cannot come round twice.
  def mount(_params, _session, socket), do: {:ok, redirect(socket, to: ~p"/")}

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
       when action in [:town, :gatekeeper, :hunt, :trader, :trainer],
       do: {Atom.to_string(action), Paths.town_of(uri)}

  defp requested_place(:highscores, uri, _player), do: {"highscores", Paths.lineage_of(uri)}

  defp requested_place(:trader_page, uri, _player),
    do:
      {"trader-" <> (uri |> URI.parse() |> Map.fetch!(:path) |> Path.basename()),
       Paths.town_of(uri)}

  defp requested_place(action, _uri, _player), do: {Atom.to_string(action), nil}

  defp enter(socket, {screen, town}) do
    fresh? = socket.assigns.flash_fresh
    # A flash survives exactly one arrival, so an action that flashes and moves you does not clear
    # its own message.
    socket =
      if socket.assigns.flash_fresh,
        do: assign(socket, flash_fresh: false),
        else: assign(socket, game_flash: nil)

    socket
    |> disengage_unless(screen == "hunt")
    |> follow_board(screen == "highscores")
    |> assign(
      screen: screen,
      town: town,
      # A choice belongs to the screen it was made on, and so does the last fight, unless the fight
      # is what brought the character there.
      picked: nil,
      picks: %{},
      fight: if(screen == "hunt" and fresh?, do: socket.assigns.fight),
      dev_name:
        if(screen == "start" and socket.assigns.debug, do: Math.random_element(@dev_names)),
      page_title: Screens.page_title(screen, socket.assigns.view),
      # Assigned, not computed in the template: an expression over `assigns` is re-sent on every
      # render.
      panels: Screens.panels(screen, socket.assigns.view, socket.assigns.catalog),
      # A fault belongs to the error screen it brought you to, not to the next visit to it.
      error_detail: if(screen == "error", do: socket.assigns.error_detail)
    )
  end

  # Rules §20: leaving the ground by any road (the banner, a link) disengages as retreating does.
  defp disengage_unless(socket, true), do: socket

  defp disengage_unless(%{assigns: %{player: %{combat: "engaged"}}} = socket, false) do
    {_, player} =
      Characters.mutate(socket.assigns.session_id, &{MiniLineage.Game.Player.disengage(&1), :ok})

    assign(socket, player: player, view: Snapshot.build(player))
  end

  defp disengage_unless(socket, false), do: socket

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

  @inner ~w(trader trainer) ++ Enum.map(Paths.trader_pages(), &("trader-" <> &1))

  # Rules §20: going out to the ground is the first fight, as the legacy Battleground was.
  def handle_event("navigate", %{"place" => "hunt"}, socket),
    do:
      {:noreply, socket |> apply_action(&Actions.hunt/1, &{"hunt", &1.location}) |> keep_fight()}

  def handle_event("navigate", %{"place" => place}, socket) when place in @inner,
    do: {:noreply, walk(socket, {place, socket.assigns.town})}

  # The empty choice of a menu inside a town goes back to the town.
  def handle_event("navigate", %{"place" => ""}, socket),
    do: {:noreply, walk(socket, {"town", socket.assigns.player.location})}

  def handle_event("navigate", _params, socket), do: {:noreply, socket}

  # Rules §23 and §24: what a character carries, bought, sold, put on and taken off where it stands.
  # A trader's page: its empty choice goes back to the trader's menu.
  def handle_event("buy", %{"item" => ""}, socket),
    do: {:noreply, walk(socket, {"trader", socket.assigns.town})}

  def handle_event("buy", %{"item" => name}, socket),
    do: {:noreply, apply_action(socket, &Actions.buy(&1, name), nil)}

  def handle_event("sell", %{"id" => ""}, socket),
    do: {:noreply, walk(socket, {"trader", socket.assigns.town})}

  def handle_event("sell", %{"id" => id}, socket),
    do: {:noreply, apply_action(socket, &Actions.sell(&1, id), nil)}

  # The inventory's one choice: what to do, and to which item.
  # The inventory: one item picked and put on or taken off, whichever it needs; its empty choice
  # goes back to town. Destroying is a form of its own, whose empty choice does nothing.
  def handle_event("wear", %{"id" => ""}, socket),
    do: {:noreply, walk(socket, {"town", socket.assigns.player.location})}

  def handle_event("wear", %{"id" => id}, socket) do
    equipped? = Enum.any?(socket.assigns.player.items, &(&1.id == id and &1.equipped))
    action = if equipped?, do: &Actions.unequip(&1, id), else: &Actions.equip(&1, id)
    {:noreply, apply_action(socket, action, nil)}
  end

  def handle_event("destroy", %{"doomed" => ""}, socket), do: {:noreply, socket}

  def handle_event("destroy", %{"doomed" => id}, socket),
    do: {:noreply, apply_action(socket, &Actions.destroy(&1, id), nil)}

  # Rules §25: one line from the village's trainer, chosen as "skill|level"; the empty choice leaves.
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

  # Rules §20: one click, one fight, staying on the ground unless it ends the run. A fight the hunter
  # walks away from is written on the ground's page; one that ends the run keeps its alert.
  def handle_event("hunt", _params, socket),
    do: {:noreply, socket |> apply_action(&Actions.hunt/1, nil) |> keep_fight()}

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
  defp dev(socket, :level), do: apply_action(socket, &Actions.dev_level/1, nil)
  defp dev(socket, :max_level), do: apply_action(socket, &Actions.dev_max_level/1, nil)

  # Every page redraws, not only this one: the hour is the world's.
  defp dev(socket, time) when time in [:night, :day] do
    :ok = Clock.force(time)
    Phoenix.PubSub.broadcast(MiniLineage.PubSub, @world, :world_changed)

    text =
      "A debug build holds the world at #{time}, whatever the hour, until the server restarts."

    assign(socket, game_flash: %{text: text, type: :info})
  end

  # TEMPORARY, for trying every race and path from one browser: deletes the character outright.
  defp dev(socket, :quit) do
    id = socket.assigns.session_id
    Characters.forget(id)
    Characters.attach(id)
    player = Characters.snapshot(id)

    socket
    |> assign(player: player, view: Snapshot.build(player), game_flash: nil)
    |> go({"start", nil})
  end

  # A fight the hunter lives through is written on the ground's page rather than in an alert.
  defp keep_fight(%{assigns: %{game_flash: %{log: _} = fight, view: %{started: true}}} = socket),
    do: assign(socket, fight: fight, game_flash: nil)

  defp keep_fight(socket), do: socket

  # ----------------------------------------------------------------- pushes

  @impl true
  # The echo of this tab's own action, which `apply_action/3` has already folded in.
  def handle_info({:character_updated, player}, %{assigns: %{player: player}} = socket),
    do: {:noreply, socket}

  def handle_info({:character_updated, player}, socket) do
    socket = assign(socket, player: player, view: Snapshot.build(player))
    place = {socket.assigns.screen, socket.assigns.town}
    target = Access.pin_screen(place, player)

    {:noreply, if(target == place, do: socket, else: go(socket, target))}
  end

  # A push already queued when the reader left the Halls is dropped.
  def handle_info({:board, boards}, %{assigns: %{following_board: true}} = socket),
    do: {:noreply, assign(socket, boards: boards)}

  def handle_info({:board, _boards}, socket), do: {:noreply, socket}

  # Rules §15: nightfall changes nothing the character's process stores, so nothing is pushed for it.
  # The page wakes itself at the exact moment instead, and redraws what the hour changes.
  def handle_info(:world_changed, socket),
    do: {:noreply, assign(socket, view: Snapshot.build(socket.assigns.player))}

  def handle_info(:dusk_or_dawn, socket) do
    await_dusk_or_dawn()
    {:noreply, assign(socket, view: Snapshot.build(socket.assigns.player))}
  end

  # ------------------------------------------------------------------ plumbing

  # A beat past the boundary, so the redraw reads the new hour and not the last of the old one.
  defp await_dusk_or_dawn do
    now = Clock.now()

    Process.send_after(
      self(),
      :dusk_or_dawn,
      DateTime.diff(Clock.next_boundary(now), now, :millisecond) + 50
    )
  end

  # A refusal stays on the screen it was raised on; a success goes on to where the action leads, a
  # place worked out from the player it left, or nowhere for nil. `catch` is for the process exiting.
  defp apply_action(socket, fun, to) do
    {result, player} = Characters.mutate(socket.assigns.session_id, fun)
    socket = assign(socket, player: player, view: Snapshot.build(player))

    case result do
      {:error, _code, message} -> assign(socket, game_flash: %{text: message, type: :danger})
      {:ok, flash} -> socket |> assign(game_flash: flash) |> play(flash[:sound]) |> arrive(to)
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

  # Staying put, unless what happened moved the character's place: a death sends it to game start.
  defp arrive(socket, nil) do
    place = {socket.assigns.screen, socket.assigns.town}
    target = Access.pin_screen(place, socket.assigns.player)

    if target == place, do: socket, else: go(socket, target)
  end

  defp arrive(socket, to), do: go(socket, to.(socket.assigns.player))

  defp here(player), do: {"town", player.location}

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
      dev_keys={@debug and @view.started}
    >
      <Controls.flash_alert :if={@game_flash && panel == hd(@panels)} flash={@game_flash} />

      <Screens.screen
        screen={@screen}
        panel={panel}
        view={@view}
        catalog={@catalog}
        detail={@error_detail}
        picked={@picked}
        debug={@debug}
        dev_name={@dev_name}
        boards={@boards}
        lineage={@town}
        character_id={@character_id}
        fight={@fight}
        picks={@picks}
      />
    </Layouts.app>
    """
  end
end
