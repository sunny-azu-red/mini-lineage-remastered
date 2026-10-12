defmodule MiniLineage.Game.Narratives do
  @moduledoc "Narrative templates."

  # They/them takes the same verb forms as you, so only the pronouns move between the two voices.
  @voices %{
    true => %{
      they: "You",
      them: "you",
      object: "you",
      their: "your"
    },
    false => %{
      they: "They",
      them: "they",
      object: "them",
      their: "their"
    }
  }

  @began ~s({they} chose the {raceEmoji} {className} and set out from {townEmoji} {town}.)

  @arrived ~s({they} pay the Gatekeeper <span class="adena">{fee} Adena</span> and step out into {townEmoji} {town}.)

  # Rules §20: a kill, and what it paid. `{adena}` is empty when the monster carried none.
  @slew ~s({they} cut down the {monster} at the {ground} and take <span class="xp">{exp} XP</span> and <span class="sp">{sp} SP</span>{adena}.)
  @levelled ~s({they} reach <span class="level">Level {level}</span>, and {their} wounds close.)
  # Rules §21: the line a run ends on, kept with it.
  @fell ~s({they} fall to the {monster} at the {ground}, and {their} road ends here.)
  @wandered ~s({they} cannot bring the {monster} down, and it slinks away into the {ground}.)

  # Rules §20's fight log: who is met, then each round's events joined into one line.
  @met ~s({they} meet {article} {monster}, level <span class="level">{level}</span>, on the {ground}.)
  # Each follows "Round N:", so its subject is {them}, the lowercase one.
  @log %{
    blow: ~s({them} hit for {amount}),
    critical: ~s({them} land a critical hit for <span class="crit">{amount}</span>),
    miss: "{them} miss",
    skill: ~s({their} {skill} deals <span class="attack">{amount}</span>),
    skill_failed: "{their} {skill} fails to land",
    cast: ~s({them} cast {skill} for <span class="magic">{amount}</span>),
    magic_critical: ~s({their} {skill} strikes true for <span class="crit">{amount}</span>),
    ignite: "{them} set it burning with {skill}",
    burn: ~s(it burns for <span class="magic">{amount}</span>),
    foe_blow: ~s(the {monster} hits {object} for <span class="hp">{amount}</span>),
    foe_critical:
      ~s(the {monster} lands a critical hit on {object} for <span class="hp">{amount}</span>),
    foe_caught:
      ~s({their} shield catches the {monster}'s blow, and {them} take <span class="hp">{amount}</span>),
    foe_perfect: "{their} shield turns the {monster}'s blow aside",
    foe_miss: "the {monster} misses",
    draw: "{them} draw {their} bow",
    ready: "{them} close in for the next blow",
    casting: "{them} keep casting",
    standing:
      ~s|<span class="muted">(the {monster} at <span class="hp">{foe}</span> of {foe_max} HP, {them} at <span class="hp">{hp}</span> of {max})</span>|,
    foe_cast: ~s(the {monster} casts {skill} on {object} for <span class="hp">{amount}</span>),
    heal: ~s({them} cast {skill} and mend <span class="buff">{amount}</span> HP),
    aura: ~s({them} raise {their} <span class="buff">{skill}</span>),
    toggle:
      ~s({them} let out a <span class="buff">{skill}</span>, and {their} blows grow heavier),
    curse: ~s({them} lay {skill} on the {monster}),
    curse_failed: "{their} {skill} slides off the {monster}",
    poison: ~s(the poison eats <span class="magic">{amount}</span>),
    potion: ~s({them} drink a {potion} and mend <span class="buff">{amount}</span> HP)
  }

  def met, do: @met
  def log(kind), do: Map.fetch!(@log, kind)

  def slew, do: @slew
  def levelled, do: @levelled
  def fell, do: @fell
  def wandered, do: @wandered
  def arrived, do: @arrived
  def began, do: @began

  @doc "The pronoun set a template is filled from: the reader's own, or somebody else's."
  def voice(mine?), do: Map.fetch!(@voices, mine?)
end
