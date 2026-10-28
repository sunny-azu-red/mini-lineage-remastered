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
  @slew ~s({they} cut down the {monster} at the {ground} and take <span class="xp">{exp} XP</span> and {sp}{adena}.)
  # The gold alert a new level raises over the page, beside the fight's own line: the client's
  # system message 96 (docs/canon/skills.md).
  @levelled "{Their} level has increased!"
  # Rules §21: the blow a run ends on. The ground's panel is headed Game Over, so this only says who.
  @fell ~s({they} fall to the {monster} at the {ground}.)
  @wandered ~s({they} cannot bring the {monster} down, and it slinks away into the {ground}.)
  # Rules §21: the one line a fallen run's ground tells, what becomes of it. The Monument of Heroes
  # is the obelisk that stands in every town, and Shilen the goddess of death (docs/canon/death.md).
  @epitaph ~s(Shilen, the goddess of death, has gathered {their} soul but not {their} name, which the Monument of Heroes keeps in every town of Aden among all who fought before {object}.)

  # Rules §20's fight log: who is met, then each round told one sentence per side.
  @met ~s({they} meet {article} {monster}, <span class="level">Level {level}</span>, on the {ground}.)
  # Rules §20: an aggressive monster finds the character first.
  @noticed ~s({Article} {monster}, <span class="level">Level {level}</span>, notices {object} on the {ground} and comes at {object}.)
  # Each may stand inside a sentence, so it is written lowercase; `Narrative` capitalises whichever
  # opens one. Every attack names its motion, then its outcome: {motion} is the character's
  # "swing {their} 🗡️ Long Sword", "shoot {their} 🏹 Bow", "punch with {their} 🥊 Cestus" or, bare
  # handed, "punch", and a monster's "swings" or "shoots", with "twice" or "3 times" when there was
  # more than one. Every {skill}, {potion}, {weapon} and {shield} is named through `Names`.
  @log %{
    # {amount} is every hit's figure, "42 and 41 damage", built by `Narrative`.
    blow: ~s({them} {motion} and hit for {amount}{overkill}),
    critical:
      ~s({them} {motion} and land a critical hit for <span class="crit">{amount} damage</span>{overkill}),
    miss: "{them} {motion} and miss",
    misses: "{them} {motion} and miss {every}",
    swings: "{them} {motion}: {outcomes}",
    skill: ~s({them} use {skill} for <span class="attack">{amount} damage</span>{overkill}),
    skill_missed: "{them} use {skill} and miss",
    cast: ~s({them} cast {skill} for <span class="magic">{amount} damage</span>{overkill}),
    magic_critical:
      ~s({them} cast {skill} and land a critical hit for <span class="crit">{amount} damage</span>{overkill}),
    drain:
      ~s({them} cast {skill} for <span class="magic">{amount} damage</span>{overkill} and mend <span class="regen">{healed} HP</span>{overheal}),
    drain_critical:
      ~s({them} cast {skill} and land a critical hit for <span class="crit">{amount} damage</span>{overkill}, mending <span class="regen">{healed} HP</span>{overheal}),
    ignite: "{them} set the {monster} burning with {skill}",
    # What a burn or a poison takes each round, named for the spell that laid it.
    burn:
      ~s({their} {skill} burns the {monster} for <span class="magic">{amount} damage</span>{overkill}),
    poison:
      ~s({their} {skill} eats at the {monster} for <span class="magic">{amount} damage</span>{overkill}),
    foe_blow: ~s(the {monster} {motion} and hits {object} for {amount}{overkill}),
    foe_critical:
      ~s(the {monster} {motion} and lands a critical hit on {object} for <span class="crit">{amount} damage</span>{overkill}),
    foe_caught:
      ~s(the {monster} {motion} and hits {their} {shield} for <span class="hp">{amount} damage</span>{overkill}),
    foe_perfect:
      ~s(the {monster} {motion} and glances off {their} {shield} for <span class="hp">{amount} damage</span>{overkill}),
    foe_miss: "the {monster} {motion} and misses",
    foe_misses: "the {monster} {motion} and misses {every}",
    foe_swings: "the {monster} {motion}: {outcomes}",
    draw: "{them} draw {their} {weapon}",
    ready: "{them} close in for the next blow",
    begin: "{them} begin casting {skill}",
    # Lineage II's "Not enough MP.", said once, in the round the spell would have been cast.
    no_mp: "{them} lack the MP for {skill}",
    # Opens a round's first sentence while a cast goes on, so it says why the character did
    # nothing: "as you cast, the Orc swings and hits you for 18 damage".
    casting: "as {them} cast,",
    foe_begin: "the {monster} begins casting {skill}",
    closing: "the {monster} runs at {object}",
    advancing: "{them} run at the {monster}",
    foe_cast:
      ~s(the {monster} casts {skill} on {object} for <span class="hp">{amount} damage</span>{overkill}),
    foe_drain:
      ~s(the {monster} casts {skill} on {object} for <span class="hp">{amount} damage</span>{overkill} and mends <span class="regen">{healed} HP</span>{overheal}),
    # Each of a side's swings in a round, in order, when they did not all hit or all miss.
    swing_hit: ~s(a hit of <span class="attack">{amount} damage</span>{overkill}),
    swing_critical: ~s(a critical hit of <span class="crit">{amount} damage</span>{overkill}),
    swing_miss: "a miss",
    foe_swing_hit: ~s(a hit of <span class="hp">{amount} damage</span>{overkill}),
    foe_swing_critical: ~s(a critical hit of <span class="crit">{amount} damage</span>{overkill}),
    foe_swing_caught:
      ~s(a hit of <span class="hp">{amount} damage</span>{overkill} on {their} {shield}),
    foe_swing_perfect:
      ~s(a glancing blow of <span class="hp">{amount} damage</span>{overkill} off {their} {shield}),
    # {times} is "" or, for the same heal cast again before the pull, " twice".
    heal:
      ~s({them} cast {skill}{times} and mend <span class="regen">{amount} HP</span>{overheal}),
    aura: "{them} raise {their} {skill}",
    toggle: "{them} let out a {skill} to make {their} blows heavier",
    curse: ~s({them} lay {skill} on the {monster}),
    curse_failed: "{their} {skill} slides off the {monster}",
    potion: ~s({them} drink a {potion} and mend <span class="regen">{amount} HP</span>{overheal})
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
  def levelled, do: @levelled
  def fell, do: @fell
  def wandered, do: @wandered
  def epitaph, do: @epitaph
  def arrived, do: @arrived
  def began, do: @began

  @doc "The pronoun set a template is filled from: the reader's own, or somebody else's."
  def voice(mine?), do: Map.fetch!(@voices, mine?)
end
