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

  alias MiniLineage.Game.{Access, Actions, Clock, Math, Player, Snapshot, Version}
  alias MiniLineageWeb.{Controls, Paths, Screens}

  # Debug builds only: a name already written on game start, so trying another race is one click.
  @dev_names ~w(Aerin Baelor Cadmus Darion Elowen Fenris Galen Hadrian Isolde Jorah Kaelith Lucan
                Morwen Nerys Orin Perrin Quill Rowan Sorcha Talia Ulric Vesper Wren Ysolde)

  @impl true
  def mount(_params, %{"session_id" => id}, socket) when is_binary(id) do
    if connected?(socket) do
      Characters.attach(id)
      Characters.subscribe(id)
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
       picked: nil,
       dev_name: nil,
       keys: "",
       title: nil,
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

  defp requested_place(action, uri, _player) when action in [:town, :gatekeeper],
    do: {Atom.to_string(action), Paths.town_of(uri)}

  defp requested_place(action, _uri, _player), do: {Atom.to_string(action), nil}

  defp enter(socket, {screen, town}) do
    # A flash survives exactly one arrival, so an action that flashes and moves you does not clear
    # its own message.
    socket =
      if socket.assigns.flash_fresh,
        do: assign(socket, flash_fresh: false),
        else: assign(socket, game_flash: nil)

    assign(socket,
      screen: screen,
      town: town,
      # A choice belongs to the screen it was made on.
      picked: nil,
      dev_name:
        if(screen == "start" and socket.assigns.debug, do: Math.random_element(@dev_names)),
      page_title: Screens.page_title(screen, socket.assigns.view),
      # Assigned, not computed in the template: an expression over `assigns` is re-sent on every
      # render.
      title: Screens.title(screen, socket.assigns.view),
      # A fault belongs to the error screen it brought you to, not to the next visit to it.
      error_detail: if(screen == "error", do: socket.assigns.error_detail)
    )
  end

  # ----------------------------------------------------------------- events

  @impl true
  def handle_event("start", %{"name" => name, "race_id" => race_id} = params, socket) do
    path = params["path"]
    {:noreply, apply_action(socket, &Actions.start(&1, race_id, path, name), &here/1)}
  end

  # A choice relabels its button before it is acted on.
  def handle_event("pick", %{"_target" => [field]} = params, socket),
    do: {:noreply, assign(socket, picked: params[field])}

  # Somewhere inside the town, which is where you stand already: a patch, never a write.
  def handle_event("navigate", %{"place" => "gatekeeper"}, socket),
    do: {:noreply, go(socket, {"gatekeeper", socket.assigns.town})}

  # TEMPORARY, for trying every race and path from one browser: deletes the character outright.
  # A release neither offers it nor answers it.
  def handle_event("navigate", %{"place" => "quit"}, %{assigns: %{debug: true}} = socket) do
    id = socket.assigns.session_id
    Characters.forget(id)
    Characters.attach(id)
    player = Characters.snapshot(id)

    {:noreply,
     socket
     |> assign(player: player, view: Snapshot.build(player), game_flash: nil)
     |> go({"start", nil})}
  end

  def handle_event("navigate", _params, socket), do: {:noreply, socket}

  # The Gatekeeper's empty choice is the way back into town.
  def handle_event("travel", %{"to" => ""}, socket),
    do: {:noreply, go(socket, {"town", socket.assigns.town})}

  def handle_event("travel", %{"to" => to}, socket),
    do: {:noreply, apply_action(socket, &Actions.travel(&1, to), &here/1)}

  # Debug builds only: typing `adena` anywhere but a text field. The letters are kept here, never
  # in the character, so nothing about them is persisted.
  def handle_event("key", %{"key" => <<key>>}, %{assigns: %{debug: true}} = socket)
      when key in ?a..?z do
    keys = String.slice(socket.assigns.keys <> <<key>>, -5, 5)

    if keys == "adena",
      do: {:noreply, socket |> assign(keys: "") |> apply_action(&Actions.dev_adena/1, nil)},
      else: {:noreply, assign(socket, keys: keys)}
  end

  def handle_event("key", _params, socket), do: {:noreply, socket}

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

  # Rules §15: nightfall changes nothing the character's process stores, so nothing is pushed for it.
  # The page wakes itself at the exact moment instead, and redraws what the hour changes.
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

  defp arrive(socket, nil), do: socket
  defp arrive(socket, to), do: go(socket, to.(socket.assigns.player))

  defp here(player), do: {"town", player.location}

  defp play(socket, nil), do: socket
  defp play(socket, sound), do: push_event(socket, "play-sound", %{name: sound})

  # Withheld outside a debug build: a player is never handed a stack.
  defp fail(socket, detail) do
    detail = if Version.debug_build?(), do: detail

    socket |> assign(error_detail: detail) |> go({"error", nil})
  end

  defp go(socket, place),
    do: socket |> assign(flash_fresh: true) |> push_patch(to: Paths.for_screen(place))

  # ------------------------------------------------------------------ render

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app title={@title} view={@view} screen={@screen} dev_keys={@debug and @view.started}>
      <Controls.flash_alert :if={@game_flash} flash={@game_flash} />

      <Screens.screen
        screen={@screen}
        view={@view}
        catalog={@catalog}
        detail={@error_detail}
        picked={@picked}
        debug={@debug}
        dev_name={@dev_name}
      />
    </Layouts.app>
    """
  end
end
