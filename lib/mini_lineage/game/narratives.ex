defmodule MiniLineage.Game.Narratives do
  @moduledoc "Narrative templates. Each list is drawn from by index, so ORDER is load-bearing."

  @race_traits %{
    0 =>
      ~s(They embark with a versatile <span class="hp">{hp} HP</span> and a starting inheritance of <span class="adena">🪙 {adena} Adena</span>, striking with a steady <span class="crit">{crit}% Critical Chance</span>. Their adaptable biology allows for <span class="regen">+{regen} Regeneration</span> during moments of rest, while their vigilant focus maintains a balanced <span class="ambush">{ambush}% Ambush Risk</span>.),
    1 =>
      ~s(They embark with a fortified <span class="hp">{hp} HP</span> and a starting tribute of <span class="adena">🪙 {adena} Adena</span>, though their raw, unweighted strikes offer a <span class="crit">{crit}% Critical Chance</span>. Their iron-like biology denies them natural mending, requiring constant sustenance to fuel their recovery, while their unmistakable presence yields a <span class="ambush">{ambush}% Ambush Risk</span>.),
    2 =>
      ~s(They embark with a slight <span class="hp">{hp} HP</span> but a vast ancestral treasury of <span class="adena">🪙 {adena} Adena</span>, striking with a graceful <span class="crit">{crit}% Critical Chance</span>. Their spiritual biology allows for a potent <span class="regen">+{regen} Regeneration</span> during moments of rest, while their ethereal nature limits the threat of the shadows to a mere <span class="ambush">{ambush}% Ambush Risk</span>.),
    3 =>
      ~s(They embark with a tempered <span class="hp">{hp} HP</span> and a starting wealth of <span class="adena">🪙 {adena} Adena</span>, striking with a lethal <span class="crit">{crit}% Critical Chance</span>. Their shadow-touched biology allows for a swift <span class="regen">+{regen} Regeneration</span> during moments of rest, while their predatory focus keeps the danger of the road at a low <span class="ambush">{ambush}% Ambush Risk</span>.)
  }

  # What each effect does, in the page's own voice: `{them}` is the subject mid-sentence, `{object}`
  # the object, `{their}` the possessive, `{self}` the reflexive. Keyed by the ACTIVE id, which is
  # what a view carries.
  @effect_blurbs %{
    "ghost" =>
      ~s(The road is behind {object} now, and nothing of it walks with {object} any more...),
    "resting" =>
      ~s(No blade is drawn where {them} stand. Out of the fray {their} wounds have leave to knit, and what the road keeps in the dark is somebody else's trouble for now.),
    "combat" =>
      ~s(Steel is out and the air will not settle. Nothing mends while it is drawn, and until the fray lets go the roads out of it stay shut.),
    "regenerating" =>
      ~s(Rest is doing its quiet work: <span class="regen">{regen} HP</span> knits back with every turn of the cycle, and will go on doing so until {them} stand whole again.),
    "newbie_blessing" =>
      ~s(The realm is gentle with the newly born, though it does not stay gentle long. It lends {object} <span class="hp">{max_health} Max HP</span> and <span class="defense">{defense} Physical Defense</span>, and turns the road's eye aside for <span class="ambush">{ambush_risk}% Ambush Risk</span>.),
    "hexed" =>
      ~s(Something took {their} measure in the ambush and has not looked away since. The roads find {object} the easier for it at <span class="ambush">{ambush_risk}% Ambush Risk</span>, and {their} own aim is the poorer at <span class="crit">{crit}% Critical Hit Chance</span>.),
    "konami_cheat" =>
      ~s(The gods were watching, and they paid to the letter: <span class="xp">{xp_multiplier}x XP</span>, <span class="adena">{adena_multiplier}x Adena</span>, <span class="crit">{crit}% Critical Hit Chance</span> and <span class="hp">{max_health} Max HP</span>. None of it fades, nor does what it cost, because the Halls rank the living and the fallen alike, and they will not rank {object}, however far {them} go.),
    "satisfied" =>
      ~s(A hot meal sits well, and a body that is fed is a body that holds together: <span class="hp">{max_health} Max HP</span> for as long as it lasts.),
    "well_fed" =>
      ~s(Properly fed for once, and it shows in the way {them} carry {self}: <span class="hp">{max_health} Max HP</span> while the meal holds.),
    "gourmet_feast" =>
      ~s(A table fit for somebody who will not see the week out, and worth every coin of it: <span class="hp">{max_health} Max HP</span> stand between {object} and the dark.)
  }

  # Open pronouns like every other stored line: this one greets the player as a flash and is kept
  # in the Chronicle, where a stranger reads it about them rather than to them.
  @welcome [
    "{their} destiny awaits in the dark!",
    "the fires of fate burn for {object}...",
    "a hero rises from the ashes now!",
    "the world of Aden calls to {object}...",
    "blood and iron define {their} soul!",
    "steel and magic are {their} allies!",
    "ancient echoes follow {their} feet!",
    "a bold step toward {their} destiny!",
    "{their} spirit shines in the dark..."
  ]

  # The pronouns every voiced template is filled from. They/them takes the same verb forms as you,
  # so a sentence written once reads correctly either way — nothing but these words moves.
  @voices %{
    true => %{
      they: "You",
      them: "you",
      object: "you",
      their: "your",
      whose: "Your",
      self: "yourself"
    },
    false => %{
      they: "They",
      them: "they",
      object: "them",
      their: "their",
      whose: "Their",
      self: "themselves"
    }
  }

  # A death is read by whoever opens the record — the fallen player, or a stranger in the Halls —
  # so it is written once with its pronouns left open rather than twice with them spelled out.
  @death [
    "🌑 The darkness takes {object}. {whose} journey ends here.",
    "👻 {whose} strength fails, and the world fades to black.",
    "💀 Fate has claimed {their} soul. Better luck in the next life.",
    "✨ {whose} life essence scatters into the aether.",
    "🩸 {whose} story has come to a sudden, bloody conclusion.",
    "🥀 {whose} light flickers out in the cold silence of the dungeon.",
    "🪦 {they} fought bravely... but not bravely enough.",
    "🦴 {whose} bones will decorate this floor for the next adventurer.",
    "🎭 {they}'ve met a terrible fate, haven't {them}?"
  ]

  # The two endings nobody is dealt: they are reached by doing something, so they are named rather
  # than drawn, and kept here with the rest of the prose all the same.
  @death_cheated "👾 The gods saw {their} heresy and cast {their} memory into oblivion."
  @death_coward "🤡 {they} took the cowardly way out."

  @ambush_low_health [
    "Your warm blood stains the ancient, cold earth of Aden...",
    "Death's cold, heavy shadow looms darkly over your soul...",
    "One more crushing blow will surely be your absolute last...",
    "Your vision fades into darkness as you stumble forward...",
    "Your strength fails you now and the bitter end is very near...",
    "Each shallow breath is a desperate struggle for survival...",
    "The golden flame of your life flickers low in the wind...",
    "Fate's golden thread is frayed, thin, and ready to snap...",
    "The eternal aether calls out to your weary, fading soul..."
  ]

  @kill [
    ~s(Wielding {their} {weaponEmoji} <span class="equipped">{weaponName}</span> with fury, {them} cut down <span class="kills">{enemyGroup}</span>.),
    ~s({whose} {weaponEmoji} <span class="equipped">{weaponName}</span> cleaves through the battlefield, slaying <span class="kills">{enemyGroup}</span>.),
    ~s(With a fierce war cry {them} lunge forward, striking down <span class="kills">{enemyGroup}</span> with {their} {weaponEmoji} <span class="equipped">{weaponName}</span>.),
    ~s(The <span class="kills">{enemyGroup}</span> stood no chance against {their} {weaponEmoji} <span class="equipped">{weaponName}</span>, which cut {isSingleEnemy ? 'it' : 'them'} down swiftly.),
    ~s(A lethal dance of {their} {weaponEmoji} <span class="equipped">{weaponName}</span> leaves <span class="kills">{enemyGroup}</span> fallen in {their} wake.),
    ~s({whose} strike is true. The {weaponEmoji} <span class="equipped">{weaponName}</span> finds its mark against <span class="kills">{enemyGroup}</span>.)
  ]

  @deflection [
    ~s({whose} {armorEmoji} <span class="equipped">{armorName}</span> absorbed a total of <span class="damage">{blocked} Damage</span>, but {them} still learned from the clash, earning <span class="xp">{xpGained} XP</span>.),
    ~s(The {armorEmoji} <span class="equipped">{armorName}</span> held firm, deflecting <span class="damage">{blocked} Damage</span>, and the narrow escape netted {object} <span class="xp">{xpGained} XP</span>.),
    ~s(Blades glanced off {their} {armorEmoji} <span class="equipped">{armorName}</span> for <span class="damage">{blocked} Damage</span>, and {them} mastered {their} defense, granting <span class="xp">{xpGained} XP</span>.),
    ~s({whose} {armorEmoji} <span class="equipped">{armorName}</span> took the brunt of <span class="damage">{blocked} Damage</span>, yet {them} grew tougher from the blow, gaining <span class="xp">{xpGained} XP</span>.),
    ~s(Steel rings against {their} {armorEmoji} <span class="equipped">{armorName}</span>, mitigating <span class="damage">{blocked} Damage</span> as {them} refine {their} combat stance for <span class="xp">{xpGained} XP</span>.)
  ]

  @outcome [
    ~s({they} limp away with <span class="hp">{hp} HP</span> remaining and <span class="adena">🪙 {adenaGained} Adena</span> to show for it.),
    ~s(The skirmish leaves {object} at <span class="hp">{hp} HP</span>, but richer by <span class="adena">🪙 {adenaGained} Adena</span>.),
    ~s(Breathing heavily, {them} stand with <span class="hp">{hp} HP</span> left and pocket <span class="adena">🪙 {adenaGained} Adena</span>.),
    ~s(Wiping the grime of battle away, {them} survive with <span class="hp">{hp} HP</span> and claim the spoils of <span class="adena">🪙 {adenaGained} Adena</span>.)
  ]

  @level_up [
    ~s(A surge of divine energy washes over {object}! {whose} wounds vanish instantly as {them} stand tall with <span class="hp">{hp} HP</span> and <span class="adena">🪙 {adenaGained} Adena</span>.),
    ~s(Victory has sharpened {their} soul. {they} feel completely restored, clutching <span class="adena">🪙 {adenaGained} Adena</span> with <span class="hp">{hp} HP</span>.),
    ~s({they} have transcended {their} limits! {whose} body mends in a flash of light, leaving {object} invigorated at <span class="hp">{hp} HP</span> with <span class="adena">🪙 {adenaGained} Adena</span>.),
    ~s(The clash has awakened new strength within {object}. Wounds close and fatigue fades, topping {object} up to <span class="hp">{hp} HP</span> and gaining <span class="adena">🪙 {adenaGained} Adena</span>.)
  ]

  @ambush [
    "💢 Out of the blue, {ambushEnemyGroup} {isSingleAmbush ? 'surrounds' : 'surround'} {object}, and {them} can't escape.",
    "💢 {they} forget to check {their} back, and {them} get stormed by {ambushEnemyGroup}.",
    "💢 {they} find {self} in a delicate position: the {enemyEmoji} {enemyName} leader has come with reinforcements.",
    "💢 As {them} were walking along, {ambushEnemyGroup} jumped out of the bushes.",
    "💢 {they} reached a dead-end and, while turning around, {them} found {self} cornered by {ambushEnemyGroup}.",
    "💢 The ground trembles! Suddenly, {ambushEnemyGroup} {isSingleAmbush ? 'stands' : 'stand'} before {object}!",
    "💢 An arrow whistles past {their} ear... ambush! {ambushEnemyGroupCap} {isSingleAmbush ? 'emerges' : 'emerge'} from the shadows!"
  ]

  @critical [
    ~s(💥 <span class="crit">CRITICAL HIT!</span> 💥),
    ~s(🌪️ <span class="crit">DEVASTATING BLOW!</span> 🌪️),
    ~s(🔥 <span class="crit">ABSOLUTE CARNAGE!</span> 🔥),
    ~s(🎯 <span class="crit">FATAL STRIKE!</span> 🎯)
  ]

  # What a run did, one sentence apiece. Single templates rather than pools: a deed is rare next to
  # a fight, and the item is what carries the interest.
  @began ~s({they} chose the {raceEmoji} {raceLabel}, and {welcome})
  @bought_weapon ~s({they} took up the {emoji} <span class="equipped">{name}</span>.)
  @bought_armor ~s({they} put on the {emoji} <span class="equipped">{name}</span>.)
  @ate ~s({they} ate the {emoji} <span class="equipped">{name}</span> and rose to <span class="hp">{hp} HP</span>.)
  @levelled ~s({they} reached <span class="level">Level {level}</span>.)
  @heresy ~s(👾 The gods saw {their} heresy, and the Halls closed the book on {object}.)
  @effect_gained ~s({emoji} <strong class="{type}">{label}</strong> settles over {object}.)
  @effect_lapsed ~s({emoji} <strong class="{type}">{label}</strong> leaves {object}.)

  @moves [
    "Investigate the shimmering lake",
    "Search the hollow log",
    "Follow the muddy tracks",
    "Scale the castle walls",
    "Descend into the dungeon",
    "Cross the rickety bridge",
    "Examine the mossy statue",
    "Explore the foggy marsh",
    "Consult the ancient map",
    "Drink from the stone fountain",
    "Sharpen your blade",
    "Prepare for an ambush",
    "Challenge the wandering guard",
    "Scout the enemy encampment",
    "Rally your strength",
    "Set a trap in the brush",
    "Whisper a prayer to the Gods",
    "Search the fallen soldier",
    "Rest by the dying embers",
    "Scribe a note for those to follow"
  ]

  def race_traits(race_id), do: Map.fetch!(@race_traits, race_id)

  @doc "What an active effect does, or nil for one nothing has been written about yet."
  def effect_blurb(id), do: Map.get(@effect_blurbs, id)

  def welcome, do: @welcome
  def death, do: @death
  def death_cheated, do: @death_cheated
  def death_coward, do: @death_coward

  @doc "The pronoun set a template is filled from: the reader's own record, or somebody else's."
  def voice(mine?), do: Map.fetch!(@voices, mine?)

  def began, do: @began
  def bought_weapon, do: @bought_weapon
  def bought_armor, do: @bought_armor
  def ate, do: @ate
  def levelled, do: @levelled
  def heresy, do: @heresy
  def effect_gained, do: @effect_gained
  def effect_lapsed, do: @effect_lapsed

  def ambush_low_health, do: @ambush_low_health
  def kill, do: @kill
  def deflection, do: @deflection
  def outcome, do: @outcome
  def level_up, do: @level_up
  def ambush, do: @ambush
  def critical, do: @critical
  def moves, do: @moves
end
