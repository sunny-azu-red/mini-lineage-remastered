import type { MouseEvent } from 'react';
import { useGameStore } from '@/store/gameStore';
import { pluralize, formatNumber, formatAdena } from '@shared/format';
import { useAnimatedNumber } from '@/hooks/useAnimatedNumber';
import Narrative from '@/components/common/Narrative';

/**
 * Ported from character.ejs + player.view.ts's renderCharacterView. Everything needed is already
 * on `player: PlayerSnapshot` (name, race label/emoji, weapon/armor with flattened modifiers,
 * stats, xp progress, counters) plus `catalog.races` — used to look up the player's own race (for
 * backstory/traits, pre-filled HTML per plan decision A12) and, via that race's `enemyRaceId`,
 * the opponent race's label/plural/emoji for the "enemies killed" pluralized line.
 */
export default function CharacterScreen() {
    const player = useGameStore(state => state.player);
    const catalog = useGameStore(state => state.catalog);
    const navigate = useGameStore(state => state.navigate);
    // Hooks can't be called after an early return, so this is seeded even before the guard below
    // confirms `player` exists — harmless, since a 0 rendered for one impossible frame is never
    // visible (the guard bails before this component ever paints without a real player).
    const { display: hpDisplay } = useAnimatedNumber(player?.health ?? 0, { format: formatNumber });

    if (!player || !catalog || player.raceId === null || !player.weapon || !player.armor || !player.stats)
        return null;

    const race = catalog.races.find(r => r.id === player.raceId);
    const opponentRace = race ? catalog.races.find(r => r.id === race.enemyRaceId) : undefined;

    if (!race || !opponentRace)
        return null;

    const weaponCrit = player.weapon.crit ?? 0;
    const armorRegen = player.armor.regen ?? 0;

    const battlesGroup = pluralize('battle', 'battles', player.counters.totalBattles);
    const opponentRaceGroup = pluralize(
        opponentRace.label,
        opponentRace.plural,
        player.counters.totalEnemiesKilled,
        opponentRace.emoji,
    );
    const ambushesGroup = pluralize('cunning ambush', 'cunning ambushes', player.counters.totalAmbushes);

    const level = player.level ?? 0;
    const nextLevel = level + 1;

    function handleBack(e: MouseEvent<HTMLAnchorElement>) {
        e.preventDefault();
        navigate('home');
    }

    return (
        <>
            <h2>
                {race.emoji} {player.name} of {race.label} Ancestry
            </h2>
            <p>
                <Narrative html={race.backstory} />
            </p>
            <p>
                <Narrative html={race.traits} />
            </p>

            <h2>Inventory &amp; Stats</h2>
            <p>
                You are wielding the {player.weapon.emoji} {player.weapon.name} granting{' '}
                <span className="hp">
                    <span id="char-stat-attack">{formatNumber(player.stats.attack)}</span> Physical Attack
                </span>
                {weaponCrit > 0 && (
                    <>
                        {' '}
                        and <span className="crit">+{weaponCrit}% Critical Hit Chance</span>
                    </>
                )}
                , and wearing the {player.armor.emoji} {player.armor.name} providing{' '}
                <span className="muted">
                    <span id="char-stat-defense">{formatNumber(player.stats.defense)}</span> Physical Defense
                </span>
                {armorRegen > 0 && (
                    <>
                        {' '}
                        and <span className="heal">+{armorRegen} HP Regeneration</span>
                    </>
                )}
                .
            </p>
            <p>
                Combined with your ancestry, you strike with a total of{' '}
                <span className="crit">
                    <span id="char-stat-crit">{formatNumber(player.stats.crit)}</span>% Critical Hit Chance
                </span>{' '}
                and mend wounds at{' '}
                <span className="heal">
                    +<span id="char-stat-regen">{formatNumber(player.stats.regen)}</span> HP Regeneration
                </span>{' '}
                per rest cycle, while navigating the roads with a{' '}
                <span className="muted">
                    <span id="char-stat-ambush">{formatNumber(player.stats.ambushRisk)}</span>% Ambush Risk
                </span>
                .
            </p>

            <h2>The Journey So Far</h2>
            <p>
                Your journey across the realm has been defined by conflict and survival. You have fought through{' '}
                <span className="gold">{battlesGroup}</span>, slaying <span className="gold">{opponentRaceGroup}</span>{' '}
                and overcoming <span className="hp">{ambushesGroup}</span> along the road.
            </p>
            <p>
                Experience wise, you are at <span className="gold">Level {formatNumber(level)}</span> with a total of{' '}
                <span className="xp">{formatNumber(player.experience ?? 0)} XP</span>
                {!player.isMaxLevel ? (
                    <>
                        , requiring another <span className="xp">{formatNumber(player.xpNeeded)} XP</span> to reach{' '}
                        <span className="gold">Level {formatNumber(nextLevel)}</span>
                    </>
                ) : (
                    <>, standing unchallenged at the zenith of martial prowess</>
                )}{' '}
                and your vitality currently sustains you at{' '}
                <span className="hp">
                    <span id="char-hp" className="animate-val">{hpDisplay}</span> /{' '}
                    <span id="char-max-hp">{formatNumber(player.maxHealth ?? 0)}</span> HP
                </span>{' '}
                while your purse holds <span className="gold">🪙 {formatAdena(player.adena ?? 0)} Adena</span> for the
                journey ahead.
            </p>

            <p className="last back">
                <a href="#home" onClick={handleBack}>
                    Continue your journey
                </a>
            </p>
        </>
    );
}
