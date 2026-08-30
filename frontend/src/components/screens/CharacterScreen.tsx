import { useGameStore } from '@/store/gameStore';
import { pluralize, formatNumber, formatAdena } from '@shared/format';
import { useAnimatedNumber } from '@/hooks/useAnimatedNumber';
import Narrative from '@/components/common/Narrative';
import BackLink from '@/components/common/BackLink';

/**
 * Everything comes from `player: PlayerSnapshot` plus `catalog.races` — used for the player's own
 * race (backstory/traits, pre-filled HTML) and, via `enemyRaceId`, the opponent's plural forms.
 */
export default function CharacterScreen() {
    const player = useGameStore(state => state.player);
    const catalog = useGameStore(state => state.catalog);
    // Seeded before the guard below because hooks can't follow an early return. Harmless — the
    // guard bails before this component ever paints without a real player.
    const { display: hpDisplay } = useAnimatedNumber(player?.health ?? 0, { format: formatNumber });

    if (!player || !catalog || player.raceId === null || !player.weapon || !player.armor || !player.stats)
        return null;

    const race = catalog.races.find(r => r.id === player.raceId);
    const opponent = race ? catalog.races.find(r => r.id === race.enemyRaceId) : undefined;

    if (!race || !opponent)
        return null;

    const { weapon, armor, stats, counters } = player;
    const weaponCrit = weapon.crit ?? 0;
    const armorRegen = armor.regen ?? 0;
    const level = player.level ?? 0;

    return (
        <>
            <h2>{race.emoji} {player.name} of {race.label} Ancestry</h2>
            <p><Narrative html={race.backstory} /></p>
            <p><Narrative html={race.traits} /></p>

            <h2>Inventory &amp; Stats</h2>
            <p>
                You are wielding the {weapon.emoji} {weapon.name} granting{' '}
                <span className="hp">
                    <span id="char-stat-attack">{formatNumber(stats.attack)}</span> Physical Attack
                </span>
                {weaponCrit > 0 && <> and <span className="crit">+{weaponCrit}% Critical Hit Chance</span></>}
                , and wearing the {armor.emoji} {armor.name} providing{' '}
                <span className="muted">
                    <span id="char-stat-defense">{formatNumber(stats.defense)}</span> Physical Defense
                </span>
                {armorRegen > 0 && <> and <span className="heal">+{armorRegen} HP Regeneration</span></>}
                .
            </p>
            <p>
                Combined with your ancestry, you strike with a total of{' '}
                <span className="crit">
                    <span id="char-stat-crit">{formatNumber(stats.crit)}</span>% Critical Hit Chance
                </span>{' '}
                and mend wounds at{' '}
                <span className="heal">
                    +<span id="char-stat-regen">{formatNumber(stats.regen)}</span> HP Regeneration
                </span>{' '}
                per rest cycle, while navigating the roads with a{' '}
                <span className="muted">
                    <span id="char-stat-ambush">{formatNumber(stats.ambushRisk)}</span>% Ambush Risk
                </span>
                .
            </p>

            <h2>The Journey So Far</h2>
            <p>
                Your journey across the realm has been defined by conflict and survival. You have fought through{' '}
                <span className="gold">{pluralize('battle', 'battles', counters.totalBattles)}</span>, slaying{' '}
                <span className="gold">{pluralize(opponent.label, opponent.plural, counters.totalEnemiesKilled, opponent.emoji)}</span>{' '}
                and overcoming{' '}
                <span className="hp">{pluralize('cunning ambush', 'cunning ambushes', counters.totalAmbushes)}</span> along the road.
            </p>
            <p>
                Experience wise, you are at <span className="gold">Level {formatNumber(level)}</span> with a total of{' '}
                <span className="xp">{formatNumber(player.experience ?? 0)} XP</span>
                {player.isMaxLevel ? (
                    <>, standing unchallenged at the zenith of martial prowess</>
                ) : (
                    <>
                        , requiring another <span className="xp">{formatNumber(player.xpNeeded)} XP</span> to reach{' '}
                        <span className="gold">Level {formatNumber(level + 1)}</span>
                    </>
                )}{' '}
                and your vitality currently sustains you at{' '}
                <span className="hp">
                    <span id="char-hp" className="animate-val">{hpDisplay}</span> /{' '}
                    <span id="char-max-hp">{formatNumber(player.maxHealth ?? 0)}</span> HP
                </span>{' '}
                while your purse holds <span className="gold">🪙 {formatAdena(player.adena ?? 0)} Adena</span> for the
                journey ahead.
            </p>

            <BackLink />
        </>
    );
}
