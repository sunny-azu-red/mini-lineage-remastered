defmodule MiniLineageWeb.GameLive do
  @moduledoc "Placeholder for the single game LiveView — the screens land in phase 3."
  use MiniLineageWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Game Start")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} title="Game Start">
      <div id="screen" data-screen="start">
        <p>The scaffold is standing. Screens arrive in phase 3.</p>
      </div>
    </Layouts.app>
    """
  end
end
