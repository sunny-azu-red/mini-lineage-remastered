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

  alias MiniLineage.Game.{Access, Actions, Player, Snapshot, Version}
  alias MiniLineageWeb.{Controls, Paths, Screens}

  @impl true
  def mount(_params, %{"session_id" => id}, socket) when is_binary(id) do
    if connected?(socket) do
      Characters.attach(id)
      Characters.subscribe(id)
    end

    player = Characters.snapshot(id)

    {:ok,
     assign(socket,
       session_id: id,
       player: player,
       view: Snapshot.build(player),
       catalog: Snapshot.catalog(),
       screen: "start",
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
  def handle_params(_params, _uri, socket) do
    requested = requested_screen(socket.assigns.live_action, socket.assigns.player)
    pinned = Access.pin_screen(requested, socket.assigns.player)

    if pinned != requested,
      do: {:noreply, push_patch(socket, to: Paths.for_screen(pinned), replace: true)},
      else: {:noreply, enter(socket, pinned)}
  end

  # '/' is wherever the browser's own state puts it.
  defp requested_screen(:root, player),
    do: if(Player.started?(player), do: "home", else: "start")

  defp requested_screen(action, _player), do: Atom.to_string(action)

  defp enter(socket, screen) do
    # A flash survives exactly one arrival, so an action that flashes and moves you does not clear
    # its own message.
    socket =
      if socket.assigns.flash_fresh,
        do: assign(socket, flash_fresh: false),
        else: assign(socket, game_flash: nil)

    assign(socket,
      screen: screen,
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
    {:noreply, apply_action(socket, &Actions.start(&1, race_id, path, name), "home")}
  end

  # TEMPORARY, for trying every race and path from one browser: deletes the character outright.
  # A release neither draws it nor answers it.
  def handle_event("quit", _params, %{assigns: %{debug: true}} = socket) do
    id = socket.assigns.session_id
    Characters.forget(id)
    Characters.attach(id)
    player = Characters.snapshot(id)

    {:noreply,
     socket
     |> assign(player: player, view: Snapshot.build(player), game_flash: nil)
     |> go("start")}
  end

  def handle_event("quit", _params, socket), do: {:noreply, socket}

  # ----------------------------------------------------------------- pushes

  @impl true
  # The echo of this tab's own action, which `apply_action/3` has already folded in.
  def handle_info({:character_updated, player, _id}, %{assigns: %{player: player}} = socket),
    do: {:noreply, socket}

  def handle_info({:character_updated, player, _id}, socket) do
    socket = assign(socket, player: player, view: Snapshot.build(player))
    target = Access.pin_screen(socket.assigns.screen, player)

    {:noreply, if(target == socket.assigns.screen, do: socket, else: go(socket, target))}
  end

  # ------------------------------------------------------------------ plumbing

  # A refusal stays on the screen it was raised on; a success goes on to where the action leads.
  # `catch` is for the process exiting.
  defp apply_action(socket, fun, to) do
    {result, player} = Characters.mutate(socket.assigns.session_id, fun)
    socket = assign(socket, player: player, view: Snapshot.build(player))

    case result do
      {:error, _code, message} -> assign(socket, game_flash: %{text: message, type: :danger})
      {:ok, flash} -> socket |> assign(game_flash: flash) |> go(to)
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

  # Withheld outside a debug build: a player is never handed a stack.
  defp fail(socket, detail) do
    detail = if Version.debug_build?(), do: detail

    socket |> assign(error_detail: detail) |> go("error")
  end

  defp go(socket, screen),
    do: socket |> assign(flash_fresh: true) |> push_patch(to: Paths.for_screen(screen))

  # ------------------------------------------------------------------ render

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app title={@title} view={@view} screen={@screen}>
      <Controls.flash_alert :if={@game_flash} flash={@game_flash} />

      <Screens.screen screen={@screen} view={@view} catalog={@catalog} detail={@error_detail} />
      <%!-- TEMPORARY: see the "quit" event. --%>
      <Controls.button :if={@debug and @screen == "home"} id="quit" phx-click="quit">
        🚪 Quit
      </Controls.button>
    </Layouts.app>
    """
  end
end
