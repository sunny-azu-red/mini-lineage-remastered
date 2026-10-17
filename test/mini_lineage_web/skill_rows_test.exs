defmodule MiniLineageWeb.SkillRowsTest do
  @moduledoc """
  Rules §19 on the Learned Skills panel: each skill in the numbers the fight uses for this
  character, never a formula left to work out. The examples are the rules' own.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias MiniLineage.Game.{Clock, Constants, Player, Rules, Snapshot}
  alias MiniLineageWeb.Screens

  setup do
    Clock.put_now(~U[2026-07-01 12:00:00Z])
    :ok
  end

  # The set knowing every line its trainer teaches, at level 1.
  defp knowing_all(race_id, path) do
    {player, _} = Player.initialize(%Player{}, Constants.race(race_id), path, "Sunny")
    skills = for l <- Rules.lessons(Rules.set(race_id, path).name), into: %{}, do: {l.skill, 1}
    %{player | skills: skills, location: "gludio"}
  end

  test "a Fighter's skills say how often they land and when they are ready again" do
    # §19: the Human Fighter's Atk. Spd. 416 rests Power Strike 13,000 × 333 ÷ 416.
    human = page(knowing_all(0, :fighter))

    assert row(human, "power-strike") =~
             "Power 25, never missing, for 10 MP. Ready again every 10.4 seconds."

    assert figure(human, "skill-power-strike-reuse") == "104"

    # §19: a Dark Fighter's DEX 34 lands Mortal Blow 40 × 1.14 = 45.6% of the time.
    dark = page(knowing_all(3, :fighter))
    assert row(dark, "mortal-blow") =~ "Power 73, landing 45.6% of the time, for 9 MP."
    assert figure(dark, "skill-mortal-blow-lands") == "456"
    assert row(dark, "attack-aura") =~ "+8% P.Atk for 2 minutes, for 7 MP."
  end

  test "a Mystic's spells say what they mend, burn or take in HP, never √M.Atk or a power alone" do
    player = knowing_all(0, :mystic)
    stats = Player.stats(player)
    doc = page(player)

    # §19: power + √M.Atk, rounded down.
    mends = trunc(42 + :math.sqrt(stats.m_atk))
    assert row(doc, "self-heal") =~ "Mends #{mends} HP for 9 MP. Cast in "
    refute row(doc, "self-heal") =~ "√"
    assert row(doc, "ice-bolt") =~ "slowing the foe's swing and run by 30% for 2 minutes"

    orc = page(knowing_all(1, :mystic))
    assert row(orc, "chill-flame") =~ "Burns 20 HP a second for 15 seconds, 300 HP in all"
    assert row(orc, "life-drain") =~ "mending 80% of the HP it takes"

    dark = page(knowing_all(3, :mystic))
    assert row(dark, "curse-poison") =~ "240 HP in all, landing 70% of the time"
    assert row(dark, "wind-shackle") =~ "The foe swings 17% slower for 15 seconds, landing 80%"
  end

  test "a mastery reads as what it adds, as a buff does, and is never ready again" do
    fighter = %{knowing_all(1, :fighter) | skills: %{"Iron Punch" => 1, "Armor Mastery" => 3}}
    doc = page(fighter)

    assert row(doc, "armor-mastery") ==
             "🪖 Armor Mastery 3 • +14 P.Def, +3 Evasion in light armour."

    assert doc |> LazyHTML.query("#skill-armor-mastery .defense") |> LazyHTML.text() ==
             "+14 P.Def"

    assert doc |> LazyHTML.query("#skill-armor-mastery .evasion") |> LazyHTML.text() ==
             "+3 Evasion"

    # §25's decimals as the rules write them; the stat it adds to still reads whole.
    mystic = %{knowing_all(2, :mystic) | skills: %{"Wind Strike" => 1, "Robe Mastery" => 2}}
    assert row(page(mystic), "robe-mastery") == "👘 Robe Mastery 2 • +18.4 P.Def in a robe."
  end

  test "Weapon Mastery reads as a Fighter's P.Atk or a Mystic's M.Atk, a share as a buff writes it" do
    fighter = %{knowing_all(1, :fighter) | skills: %{"Iron Punch" => 1, "Weapon Mastery" => 3}}
    doc = page(fighter)
    assert row(doc, "weapon-mastery") == "🤺 Weapon Mastery 3 • +8.5% P.Atk and +4 P.Atk."

    assert doc |> LazyHTML.query("#skill-weapon-mastery .attack") |> Enum.map(&LazyHTML.text/1) ==
             ["+8.5% P.Atk", "+4 P.Atk"]

    refute row(doc, "weapon-mastery") =~ "×"

    mystic = %{knowing_all(2, :mystic) | skills: %{"Wind Strike" => 1, "Weapon Mastery" => 2}}
    doc = page(mystic)

    assert row(doc, "weapon-mastery") ==
             "🤺 Weapon Mastery 2 • +45% P.Atk and +2.8 P.Atk, +17% M.Atk and +3.5 M.Atk."

    assert doc |> LazyHTML.query("#skill-weapon-mastery .magic") |> Enum.map(&LazyHTML.text/1) ==
             ["+17% M.Atk", "+3.5 M.Atk"]

    warded = %{mystic | skills: %{"Wind Strike" => 1, "Anti Magic" => 2}}
    assert row(page(warded), "anti-magic") == "🧿 Anti Magic 2 • +16 M.Def."
  end

  test "a weapon's line says how far its blows stray" do
    {player, _} = Player.initialize(%Player{}, Constants.race(0), :fighter, "Sunny")

    sword = Enum.find(Snapshot.build(player).items, &(&1.name == "Squire's Sword"))
    assert sword.about =~ "Damage ±10%"
  end

  defp row(doc, slug), do: doc |> LazyHTML.query("#skill-#{slug}") |> LazyHTML.text() |> squish()

  defp figure(doc, key) do
    [value] = doc |> LazyHTML.query(~s([data-key="#{key}"])) |> LazyHTML.attribute("data-value")
    value
  end

  defp squish(text), do: text |> String.replace(~r/\s+/, " ") |> String.trim()

  defp page(player) do
    view = Snapshot.build(player)
    catalog = Snapshot.catalog()

    html =
      for panel <- Screens.panels("character", view, catalog), into: "" do
        render_component(&Screens.screen/1,
          screen: "character",
          panel: panel,
          view: view,
          catalog: catalog
        )
      end

    LazyHTML.from_fragment(html)
  end
end
