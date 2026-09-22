defmodule MiniLineage.Game.Access do
  @moduledoc """
  The one place every navigation rule is enforced. An in-app link, a typed URL and the Back button
  all funnel through `pin_screen/2`, so they cannot disagree — historically they did.
  """
  alias MiniLineage.Game.Player

  # The only screens a visitor with no character may reach. A character's record is one of them:
  # it is public, and linking to it from the Halls would be pointless otherwise.
  @unstarted_allowed ~w(start statistics races highscores character error)

  # Screens a living character may never be on — 'death' offers "Play Again?", which wipes them.
  @started_blocked ~w(start statistics races death)

  # What the dead may still reach. The Character screen becomes a retrospective rather than a status
  # page, and the Halls are where their run now stands — confining them to the death screen would
  # put the board they are on out of their reach. Nothing here can be acted on.
  #
  # `error` is here because something breaking is worth being told about whatever state you are in:
  # `fail/2` pushes to it when the character process exits, and without this a dead player is
  # bounced to their own ending with no sign that anything went wrong. Nothing can be acted on
  # there either, so it costs the dead nothing to be allowed to read it.
  @dead_allowed ~w(death character highscores error)

  @doc """
  Where the player is actually allowed to be. Death wins outright — checked first because killing
  a player does not clear `ambushed` — then an active ambush, then living-vs-absent character.
  """
  def pin_screen(screen, player) do
    cond do
      player.dead -> if screen in @dead_allowed, do: screen, else: "death"
      player.ambushed -> "battle"
      Player.started?(player) -> if screen in @started_blocked, do: "home", else: screen
      true -> if screen in @unstarted_allowed, do: screen, else: "start"
    end
  end

  @doc "Screens that show the sidebar. An allowlist, not derived — \"has a character\" is a different question."
  def sidebar?(screen), do: screen in ~w(home battle weapons armors inn suicide death)
end
