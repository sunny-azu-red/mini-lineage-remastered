export const RACE_TRAITS_TEMPLATES: Record<number, string> = {
    0: `They embark with a versatile <span class="hp">{hp} HP</span> and a starting inheritance of <span class="gold">🪙 {adena} Adena</span>, striking with a steady <span class="crit">{crit}% Critical Chance</span>. Their adaptable biology allows for <span class="heal">+{regen} Regeneration</span> during moments of rest, while their vigilant focus maintains a balanced <span class="muted">{ambush}% Ambush Risk</span>.`,
    1: `They embark with a fortified <span class="hp">{hp} HP</span> and a starting tribute of <span class="gold">🪙 {adena} Adena</span>, though their raw, unweighted strikes offer a <span class="crit">{crit}% Critical Chance</span>. Their iron-like biology denies them natural mending, requiring constant sustenance to fuel their recovery, while their unmistakable presence yields a <span class="muted">{ambush}% Ambush Risk</span>.`,
    2: `They embark with a slight <span class="hp">{hp} HP</span> but a vast ancestral treasury of <span class="gold">🪙 {adena} Adena</span>, striking with a graceful <span class="crit">{crit}% Critical Chance</span>. Their spiritual biology allows for a potent <span class="heal">+{regen} Regeneration</span> during moments of rest, while their ethereal nature limits the threat of the shadows to a mere <span class="muted">{ambush}% Ambush Risk</span>.`,
    3: `They embark with a tempered <span class="hp">{hp} HP</span> and a starting wealth of <span class="gold">🪙 {adena} Adena</span>, striking with a lethal <span class="crit">{crit}% Critical Chance</span>. Their shadow-touched biology allows for a swift <span class="heal">+{regen} Regeneration</span> during moments of rest, while their predatory focus keeps the danger of the road at a low <span class="muted">{ambush}% Ambush Risk</span>.`
};

export const WELCOME_MESSAGES: string[] = [
    `your destiny awaits in the dark!`,
    `the fires of fate burn for you...`,
    `a hero rises from the ashes now!`,
    `the world of Aden calls to you...`,
    `blood and iron define your soul!`,
    `steel and magic are your allies!`,
    `ancient echoes follow your feet!`,
    `a bold step toward your destiny!`,
    `your spirit shines in the dark...`
];

export const DEATH_MESSAGES: string[] = [
    `🌑 The darkness takes you. Your journey ends here.`,
    `👻 Your strength fails, and the world fades to black.`,
    `💀 Fate has claimed your soul. Better luck in the next life.`,
    `✨ Your life essence scatters into the aether.`,
    `🩸 Your story comes to a sudden, bloody conclusion.`,
    `🥀 Your light flickers out in the cold silence of the dungeon.`,
    `🪦 You fought bravely... but not bravely enough.`,
    `🦴 Your bones will decorate this floor for the next adventurer.`,
    `🎭 You've met a terrible fate, haven't you?`
];

export const AMBUSH_LOW_HEALTH_MESSAGES: string[] = [
    `Your warm blood stains the ancient, cold earth of Aden...`,
    `Death's cold, heavy shadow looms darkly over your soul...`,
    `One more crushing blow will surely be your absolute last...`,
    `Your vision fades into darkness as you stumble forward...`,
    `Your strength fails you now and the bitter end is very near...`,
    `Each shallow breath is a desperate struggle for survival...`,
    `The golden flame of your life flickers low in the wind...`,
    `Fate's golden thread is frayed, thin, and ready to snap...`,
    `The eternal aether calls out to your weary, fading soul...`
];

// ----------------
// battle templates
// ----------------

export const BATTLE_KILL_TEMPLATES: string[] = [
    `Wielding your {weaponEmoji} {weaponName} with fury, you cut down {enemyGroup}.`,
    `Your {weaponEmoji} {weaponName} cleaves through the battlefield, slaying {enemyGroup}.`,
    `With a fierce war cry you lunge forward, striking down {enemyGroup} with your {weaponEmoji} {weaponName}.`,
    `The {enemyGroup} stood no chance, your {weaponEmoji} {weaponName} ended {isSingleEnemy ? 'its' : 'their'} {isSingleEnemy ? 'life' : 'lives'} swiftly.`,
    `A lethal dance of your {weaponEmoji} {weaponName} leaves fallen {enemyGroup} in your wake.`,
    `Your strike is true. The {weaponEmoji} {weaponName} finds its mark against {enemyGroup}.`
];

export const BATTLE_DEFLECTION_TEMPLATES: string[] = [
    `Your {armorEmoji} {armorName} absorbed a total of <span class="muted">{blocked} Damage</span> but you still learned from the clash, earning <span class="xp">{xpGained} XP</span>.`,
    `The {armorEmoji} {armorName} held firm, deflecting <span class="muted">{blocked} Damage</span> and the narrow escape nets you <span class="xp">{xpGained} XP</span>.`,
    `Blades glanced off your {armorEmoji} {armorName} for <span class="muted">{blocked} Damage</span> and you mastered your defense, granting <span class="xp">{xpGained} XP</span>.`,
    `Your {armorEmoji} {armorName} took the brunt of <span class="muted">{blocked} Damage</span> yet you grow tougher from the blow, gaining <span class="xp">{xpGained} XP</span>.`,
    `Steel rings against your {armorEmoji} {armorName}, mitigating <span class="muted">{blocked} Damage</span> as you refine your combat stance for <span class="xp">{xpGained} XP</span>.`
];

export const BATTLE_OUTCOME_TEMPLATES: string[] = [
    `You limp away with <span class="hp">{hp} HP</span> remaining and <span class="gold">🪙 {adenaGained} Adena</span> to show for it.`,
    `The skirmish leaves you at <span class="hp">{hp} HP</span>, but richer by <span class="gold">🪙 {adenaGained} Adena</span>.`,
    `Breathing heavily, you stand with <span class="hp">{hp} HP</span> left and pocket <span class="gold">🪙 {adenaGained} Adena</span>.`,
    `Wiping the grime of battle away, you survive with <span class="hp">{hp} HP</span> and claim the spoils of <span class="gold">🪙 {adenaGained} Adena</span>.`
];

export const BATTLE_LEVEL_UP_TEMPLATES: string[] = [
    `A surge of divine energy washes over you! Your wounds vanish instantly as you stand tall with <span class="hp">{hp} HP</span> and <span class="gold">🪙 {adenaGained} Adena</span>.`,
    `Victory has sharpened your soul. You feel completely restored, clutching <span class="gold">🪙 {adenaGained} Adena</span> with <span class="hp">{hp} HP</span>.`,
    `You have transcended your limits! Your body mends in a flash of light, leaving you invigorated at <span class="hp">{hp} HP</span> with <span class="gold">🪙 {adenaGained} Adena</span>.`,
    `The clash has awakened new strength within you. Wounds close and fatigue fades, topping you up to <span class="hp">{hp} HP</span> and gaining <span class="gold">🪙 {adenaGained} Adena</span>.`
];

export const BATTLE_AMBUSH_TEMPLATES: string[] = [
    `Out of the blue {ambushEnemyGroup} {isSingleAmbush ? 'surrounds' : 'surround'} you and you can't escape.`,
    `You forgot to check your back and you get stormed by {ambushEnemyGroup}.`,
    `You find yourself in a delicate position, the {enemyEmoji} {enemyName} leader has come with reinforcements.`,
    `As you were walking along {ambushEnemyGroup} jumped out of the bushes.`,
    `You reached a dead-end and while turning around, you find yourself cornered by {ambushEnemyGroup}.`,
    `The ground trembles! Suddenly, {ambushEnemyGroup} {isSingleAmbush ? 'stands' : 'stand'} before you!`,
    `An arrow whistles past your ear... ambush! {ambushEnemyGroupCap} {isSingleAmbush ? 'emerges' : 'emerge'} from the shadows!`
];

export const BATTLE_CRITICAL_TEMPLATES: string[] = [
    `💥 <span class="crit">CRITICAL HIT!</span> 💥`,
    `🌪️ <span class="crit">DEVASTATING BLOW!</span> 🌪️`,
    `🔥 <span class="crit">ABSOLUTE CARNAGE!</span> 🔥`,
    `🎯 <span class="crit">FATAL STRIKE!</span> 🎯`
];

export const BATTLE_MOVES: string[] = [
    `Investigate the shimmering lake`,
    `Search the hollow log`,
    `Follow the muddy tracks`,
    `Scale the castle walls`,
    `Descend into the dungeon`,
    `Cross the rickety bridge`,
    `Examine the mossy statue`,
    `Explore the foggy marsh`,
    `Consult the ancient map`,
    `Drink from the stone fountain`,
    `Sharpen your blade`,
    `Prepare for an ambush`,
    `Challenge the wandering guard`,
    `Scout the enemy encampment`,
    `Rally your strength`,
    `Set a trap in the brush`,
    `Whisper a prayer to the Gods`,
    `Search the fallen soldier`,
    `Rest by the dying embers`,
    `Scribe a note for those to follow`
];
