defmodule MiniLineageWeb.BlessingsTest do
  @moduledoc """
  What is riding on a run, spelled out on the one page about it.

  The header wears these as emoji alone, which a phone can neither hover nor read — so what is
  asserted here is that every effect the game can apply has prose to explain it, that the prose
  speaks to whoever is reading, and that the figures in it carry their own sign.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias MiniLineage.Game.{Constants, Narratives, Player, Snapshot}
  alias MiniLineageWeb.Screens.Record

  # Carrying exactly what it is handed: a new character is given the Newbie Blessing on the way in,
  # and a fixture that kept it would answer every claim below with the same paragraph.
  defp bearer(effects) do
    {player, _} = Player.initialize(%Player{}, Constants.race(1), "Wretch")
    player = %{player | current_screen: "home", health: 10, effects: []}

    Enum.reduce(effects, player, &Player.apply_effect(&2, Constants.effect(&1)))
  end

  defp html_for(player, opts) do
    view = Snapshot.build(player)
    view = if opts[:dead], do: %{view | dead: true, death_reason: opts[:reason]}, else: view

    render_component(&Record.record/1,
      view: view,
      catalog: Snapshot.catalog(),
      entry: nil,
      mine: Keyword.get(opts, :mine, true)
    )
  end

  # The section alone, so a claim about it is not answered by the rest of the record.
  defp blessings(player, opts \\ []) do
    [_, section] =
      Regex.run(~r|Blessings &amp; Afflictions</h2>(.*?)<h2|s, html_for(player, opts))

    section
  end

  defp text(section),
    do: section |> String.replace(~r/<[^>]+>/, "") |> String.replace(~r/\s+/, " ")

  describe "every effect the game can apply" do
    # The catalog is closed and the prose is written by hand, so the two can drift apart in one
    # direction only: an effect added with no description would render as a name and nothing else.
    test "has prose written for it" do
      for {key, config} <- Constants.effects() do
        assert Narratives.effect_blurb(config.id) not in [nil, ""],
               "#{key} (#{config.id}) has no description"
      end
    end

    test "and a description that names what it does" do
      section = text(blessings(bearer([:newbie_buff])))

      assert section =~ "Newbie Blessing"
      assert section =~ "+20 Max HP"
      assert section =~ "+2 Physical Defense"
      # A modifier that takes something away says so, rather than reading as a gift.
      assert section =~ "-4% Ambush Risk"
    end

    test "with the figures coloured the way the rest of the page colours them" do
      section = blessings(bearer([:newbie_buff]))

      assert section =~ ~s(<span class="hp">+20 Max HP</span>)
      assert section =~ ~s(<span class="defense">+2 Physical Defense</span>)
      assert section =~ ~s(<span class="ambush">-4% Ambush Risk</span>)
    end

    # A multiplier is not a delta: "4x XP" is right where "+4x XP" would be nonsense.
    test "and a multiplier stated bare, not signed" do
      section = text(blessings(bearer([:konami_cheat])))

      assert section =~ "4x XP"
      assert section =~ "4x Adena"
      refute section =~ "+4x"
    end
  end

  describe "the voice" do
    test "speaks to the reader on their own record" do
      section = text(blessings(bearer([:newbie_buff]), mine: true))

      assert section =~ "It lends you"
      refute section =~ "It lends them"
    end

    test "and about them on anybody else's" do
      section = text(blessings(bearer([:newbie_buff]), mine: false))

      assert section =~ "It lends them"
      refute section =~ "It lends you"
    end
  end

  describe "an effect that lapses" do
    test "says how long is left, for the hook to keep repainting" do
      section = blessings(bearer([:ambush_debuff]))

      assert section =~ ~s(data-timer="long")
      assert section =~ ~s(data-remaining-ms=)
      assert text(section) =~ "It lifts in 1m"
    end

    test "while one that never does says nothing about a clock" do
      section = blessings(bearer([:konami_cheat]))

      # The Mark is the one debuff with no end: a countdown on it would be a lie.
      refute section =~ ~s(data-timer="long")
      refute section =~ "data-remaining-ms=\""
    end
  end

  describe "a fallen run" do
    # A reason as the game stores one: the sentence with its pronouns still open.
    @reason "🪦 {they} fought bravely... but not bravely enough."

    test "carries nothing, and says so" do
      section = text(blessings(bearer([:newbie_buff]), dead: true, reason: @reason))

      assert section =~ "Nothing walks with you any more"
      refute section =~ "Newbie Blessing"
    end

    test "and tells how it ended, here rather than at the end of the journey" do
      html = html_for(bearer([]), dead: true, reason: @reason)
      [_, before_stats] = Regex.run(~r|Blessings &amp; Afflictions</h2>(.*?)<h2|s, html)

      assert before_stats =~ "not bravely enough"
      # Once, and in the section that is about what became of them.
      assert html |> String.split("not bravely enough") |> length() == 2
    end

    test "in the reader's own voice, whoever is reading" do
      mine = text(blessings(bearer([]), dead: true, reason: @reason, mine: true))
      theirs = text(blessings(bearer([]), dead: true, reason: @reason, mine: false))

      assert mine =~ "You fought bravely"
      assert theirs =~ "They fought bravely"
    end
  end
end
