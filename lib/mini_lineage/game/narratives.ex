defmodule MiniLineage.Game.Narratives do
  @moduledoc "Narrative templates."

  # They/them takes the same verb forms as you, so only the pronouns move between the two voices.
  @voices %{
    true => %{
      they: "You",
      them: "you",
      object: "you",
      their: "your",
      Their: "Your"
    },
    false => %{
      they: "They",
      them: "they",
      object: "them",
      their: "their",
      Their: "Their"
    }
  }

  @began ~s({they} chose the {raceEmoji} {className} and set out from {townEmoji} {town}.)

  @arrived ~s({they} pay {gatekeeper} {fee} and step out into {townEmoji} {town}.)

  # Rules §20: a kill, and what it paid. `{adena}` is empty when the monster carried none.
  @slew ~s({they} cut down the {monster} at the {ground} and take <span class="xp">{exp} XP</span> and <span class="sp">{sp} SP</span>{adena}.)
  # The gold alert a new level raises over the page, beside the fight's own line.
  @congratulated ~s(🎉 Congratulations! {they} have reached <span class="level">Level {level}</span>.)
  # Rules §21: the line a run ends on, kept with it.
  @fell ~s({they} fall to the {monster} at the {ground}, and {their} road ends here.)
  @wandered ~s({they} cannot bring the {monster} down, and it slinks away into the {ground}.)
  # Rules §21: how the end is told on the ground it came on, one drawn at death and kept with the run.
  @death [
    "🌑 The darkness takes {object}. {Their} journey ends here.",
    "👻 {Their} strength fails, and the world fades to black.",
    "💀 Fate has claimed {their} soul. Better luck in the next life.",
    "✨ {Their} life essence scatters into the aether.",
    "🩸 {Their} story has come to a sudden, bloody conclusion.",
    "🥀 {Their} light flickers out in the cold silence.",
    "🪦 {they} fought bravely&hellip; but not bravely enough.",
    "🦴 {Their} bones will lie on this ground for the next adventurer to find.",
    "🎭 {they} have met a terrible fate, haven't {them}?"
  ]
  # And what becomes of it: rules §21 keeps every run on the Monument of Heroes, the obelisk that
  # stands in every town, and Shilen is the goddess of death (docs/canon/death.md).
  @epitaph ~s(Shilen, the goddess of death, has gathered {their} soul but not {their} name, which the Monument of Heroes keeps in every town of Aden among all who fought before {object}.)

  # Rules §20's fight log: who is met, then each round's events joined into one line.
  @met ~s({they} meet {article} {monster}, <span class="level">Level {level}</span>, on the {ground}.)
  # Rules §20: an aggressive monster finds the character first.
  @noticed ~s({Article} {monster}, <span class="level">Level {level}</span>, notices {object} on the {ground} and comes at {object}.)
  # Each may stand inside a round's line, so it is written lowercase; `Narrative` capitalises
  # whichever opens the line.
  @log %{
    blow: ~s({them} hit for {amount}),
    critical: ~s({them} land a critical hit for <span class="crit">{amount} damage</span>),
    miss: "{them} miss",
    skill: ~s({their} {skill} deals <span class="attack">{amount} damage</span>),
    skill_failed: "{their} {skill} fails to land",
    cast: ~s({them} cast {skill} for <span class="magic">{amount} damage</span>),
    magic_critical:
      ~s({their} {skill} strikes true for <span class="crit">{amount} damage</span>),
    drain:
      ~s({them} cast {skill} for <span class="magic">{amount} damage</span> and mend <span class="regen">{healed} HP</span>),
    drain_critical:
      ~s({their} {skill} strikes true for <span class="crit">{amount} damage</span> and mends <span class="regen">{healed} HP</span>),
    ignite: "{them} set the {monster} burning with {skill}",
    # A damage-over-time tick, named for the spell that laid it.
    burn: ~s({their} {skill} tick burns for <span class="magic">{amount} damage</span>),
    foe_blow: ~s(the {monster} hits {object} for <span class="hp">{amount} damage</span>),
    foe_critical:
      ~s(the {monster} lands a critical hit on {object} for <span class="crit">{amount} damage</span>),
    foe_caught:
      ~s({their} shield catches the {monster}'s blow, and {them} take <span class="hp">{amount} damage</span>),
    foe_perfect: "{their} shield turns the {monster}'s blow aside",
    foe_miss: "the {monster} misses",
    draw: "{them} draw {their} bow",
    ready: "{them} close in for the next blow",
    begin: "{them} begin casting {skill}",
    # Leads a round's line while a cast goes on, so it is never read as the monster's:
    # "as you cast, the Orc hits you for 18".
    casting: "as {them} cast,",
    foe_begin: "the {monster} begins casting {skill}",
    closing: "the {monster} runs at {object}",
    advancing: "{them} run at the {monster}",
    foe_cast:
      ~s(the {monster} casts {skill} on {object} for <span class="hp">{amount} damage</span>),
    foe_drain:
      ~s(the {monster} casts {skill} on {object} for <span class="hp">{amount} damage</span> and mends <span class="regen">{healed} HP</span>),
    # Two or more swings by one side in a round, each told in order.
    swings: "{them} swing {times} for {outcomes}",
    foe_swings: "the {monster} swings {times} at {object} for {outcomes}",
    misses: "{them} miss {times}",
    foe_misses: "the {monster} misses {times}",
    swing_hit: ~s(a hit of <span class="attack">{amount} damage</span>),
    swing_critical: ~s(a critical hit of <span class="crit">{amount} damage</span>),
    swing_miss: "a miss",
    foe_swing_hit: ~s(a hit of <span class="hp">{amount} damage</span>),
    foe_swing_critical: ~s(a critical hit of <span class="crit">{amount} damage</span>),
    foe_swing_caught:
      ~s(a hit of <span class="hp">{amount} damage</span> that {their} shield catches),
    foe_swing_perfect: "a blow {their} shield turns aside",
    heal: ~s({them} cast {skill} and mend <span class="regen">{amount} HP</span>),
    aura: ~s({them} raise {their} <span class="buff">{skill}</span>),
    toggle: ~s({them} let out a <span class="buff">{skill}</span> to make {their} blows heavier),
    curse: ~s({them} lay {skill} on the {monster}),
    curse_failed: "{their} {skill} slides off the {monster}",
    poison: ~s({their} {skill} tick deals <span class="magic">{amount} damage</span>),
    potion: ~s({them} drink a {potion} and mend <span class="regen">{amount} HP</span>)
  }

  # Where both stand once an entry of the fight log is done, at the right of its head. The entry
  # that meets it has named the monster; "Foe" stays apart from {they} in either voice.
  @standing ~s(Foe {foe} <span class="delimiter">&bull;</span> {they} {hp})

  # Rules §17: each village's ground, from its fields to the grounds nearby (docs/canon's places), and
  # where the hunt button sends the character next. A line sits beside Retreat on a 360px phone,
  # so it runs to 18 characters, and it names no one, being the player's own button.
  @grounds %{
    "obelisk-of-victory" => %{
      intro:
        "Monsters roam from the fields outside {townEmoji} {town} to the {ground} and the Singing Waterfall beyond it, keltirs and wolves near the walls and orcs, werewolves and spiders further out.",
      moves: [
        "Comb the fields",
        "Head east of town",
        "Track the wolves",
        "Skirt the orc camp",
        "Seek the Obelisk",
        "Follow the river",
        "Scout the woods"
      ]
    },
    "elven-fortress" => %{
      intro:
        "Monsters roam from the glades outside {townEmoji} {town} to the {ground} and the dungeon beneath it, keltirs and Kaboo orcs among the trees and skeletons and wererats in the dark below.",
      moves: [
        "Wander the glades",
        "Follow the stream",
        "Track a Kaboo orc",
        "Seek the dryads",
        "Pass the fortress",
        "Enter the dungeon",
        "Search the ruins"
      ]
    },
    "school-of-dark-arts" => %{
      intro:
        "Monsters roam from the Dark Forest outside {townEmoji} {town} to the {ground}, goblins and Balor orcs under the black trees and the undead and succubi in the School's halls.",
      moves: [
        "Walk the dark wood",
        "Under black boughs",
        "Track a Balor orc",
        "Trail the goblins",
        "Enter the School",
        "Descend the stairs",
        "Search the cellars"
      ]
    },
    "cave-of-trials" => %{
      intro:
        "Monsters roam from the prairie outside {townEmoji} {town} up onto the Immortal Plateau and down into the {ground}, Kasha wolves and Evil Eyes in the open and skeletons, ratmen and ghosts in the cave.",
      moves: [
        "Cross the prairie",
        "Track Kasha wolves",
        "Climb the Plateau",
        "Seek an Evil Eye",
        "Enter the cave",
        "Go deeper inside",
        "Search the graves"
      ]
    }
  }

  def met, do: @met
  def noticed, do: @noticed
  def log(kind), do: Map.fetch!(@log, kind)
  def standing, do: @standing

  def ground_intro(slug), do: Map.fetch!(@grounds, slug).intro
  def moves(slug), do: Map.fetch!(@grounds, slug).moves

  def slew, do: @slew
  def congratulated, do: @congratulated
  def fell, do: @fell
  def wandered, do: @wandered
  def death, do: @death
  def epitaph, do: @epitaph
  def arrived, do: @arrived
  def began, do: @began

  @doc "The pronoun set a template is filled from: the reader's own, or somebody else's."
  def voice(mine?), do: Map.fetch!(@voices, mine?)
end
