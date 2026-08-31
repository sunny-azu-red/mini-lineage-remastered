import { describe, it, expect } from 'vitest';
import { buildPlayerSnapshot, toItemView } from '@/socket/serializer/player.serializer';
import { PlayerState } from '@/interface';
import { EFFECTS_CONFIG, WEAPONS, ARMORS } from '@/constant/game.constant';
import { formatEffectTooltip } from '@/util/format.util';
import { makePlayer } from '../../factories';


describe('buildPlayerSnapshot', () => {
    describe('unstarted player', () => {
        it('returns started:false with safe empty defaults, without throwing', () => {
            expect(() => buildPlayerSnapshot({} as PlayerState)).not.toThrow();

            const snapshot = buildPlayerSnapshot({} as PlayerState);
            expect(snapshot.started).toBe(false);
            expect(snapshot.name).toBeNull();
            expect(snapshot.raceId).toBeNull();
            expect(snapshot.raceLabel).toBeNull();
            expect(snapshot.raceEmoji).toBeNull();
            expect(snapshot.health).toBeNull();
            expect(snapshot.maxHealth).toBeNull();
            expect(snapshot.hpPercent).toBe(0);
            expect(snapshot.lowHealth).toBe(false);
            expect(snapshot.experience).toBeNull();
            expect(snapshot.level).toBeNull();
            expect(snapshot.isMaxLevel).toBe(false);
            expect(snapshot.xpCurrent).toBe(0);
            expect(snapshot.xpRequired).toBe(0);
            expect(snapshot.xpPercent).toBe(0);
            expect(snapshot.xpNeeded).toBe(0);
            expect(snapshot.adena).toBeNull();
            expect(snapshot.weapon).toBeNull();
            expect(snapshot.armor).toBeNull();
            expect(snapshot.stats).toBeNull();
            expect(snapshot.effects).toEqual([]);
            expect(snapshot.dead).toBe(false);
            expect(snapshot.ambushed).toBe(false);
            expect(snapshot.coward).toBe(false);
            expect(snapshot.cheated).toBe(false);
            expect(snapshot.deathReason).toBeNull();
            expect(snapshot.highscoreEligible).toBe(false);
            expect(snapshot.counters).toEqual({
                totalBattles: 0, totalAmbushes: 0, consecutiveAmbushes: 0, totalEnemiesKilled: 0,
            });
            expect(snapshot.lastBattle).toBeNull();
        });

        it('reflects player.revision even when the game has not started', () => {
            const snapshot = buildPlayerSnapshot({ revision: 7 } as PlayerState);
            expect(snapshot.revision).toBe(7);
        });

        it('defaults revision to 0 when absent', () => {
            const snapshot = buildPlayerSnapshot({} as PlayerState);
            expect(snapshot.revision).toBe(0);
        });
    });

    describe('a started player', () => {
        it('reports raw numeric fields (formatting is the client\'s job, not this layer\'s)', () => {
            const p = makePlayer({ experience: 999_999_999 });
            const snapshot = buildPlayerSnapshot(p);

            expect(snapshot.experience).toBe(999_999_999);
            expect(typeof snapshot.level).toBe('number');
            expect(snapshot.isMaxLevel).toBe(true);
        });

        it('falls back to a null race label/emoji when raceId does not index a real race', () => {
            // A corrupt or forward-incompatible session (a race removed from the catalog) must
            // still serialize: getPlayerStats falls back to RACES[0] for the numbers, but the
            // displayed identity is reported as unknown rather than silently mislabeled Human.
            const p = makePlayer({ raceId: 99 as PlayerState['raceId'] });
            const snapshot = buildPlayerSnapshot(p);

            expect(snapshot.started).toBe(true);
            expect(snapshot.raceId).toBe(99);
            expect(snapshot.raceLabel).toBeNull();
            expect(snapshot.raceEmoji).toBeNull();
        });

        it('computes hp percent and low-health flag from live stats, not raw race maxHealth', () => {
            // Elf base maxHp 75; konami cheat buff adds +150 maxHealth => effective 225.
            const p = makePlayer({
                raceId: 2,
                health: 225,
                effects: [{ ...EFFECTS_CONFIG.konamiCheat }],
            });
            const snapshot = buildPlayerSnapshot(p);

            expect(snapshot.maxHealth).toBe(225);
            expect(snapshot.hpPercent).toBe(100);
            expect(snapshot.lowHealth).toBe(false);
        });

        it('flags low health correctly', () => {
            const p = makePlayer({ health: 5 }); // Human maxHealth 100 -> threshold 25
            const snapshot = buildPlayerSnapshot(p);
            expect(snapshot.lowHealth).toBe(true);
        });

        /**
         * The wire carries a DURATION, converted here — the one place state crosses to the client.
         * Stored state stays an absolute epoch; sending it raw made the client compare two
         * machines' clocks, and `Math.ceil` turned any error into a whole extra second.
         */
        it('maps active effects to EffectView with tooltip, emoji, and a remaining duration', () => {
            const p = makePlayer({
                effects: [{ ...EFFECTS_CONFIG.smokedSausage, expiresAt: Date.now() + 25_000 }],
            });
            const snapshot = buildPlayerSnapshot(p);

            const effect = snapshot.effects.find(e => e.id === 'satisfied');
            expect(effect).toBeDefined();
            expect(effect?.emoji).toBe(EFFECTS_CONFIG.smokedSausage.emoji);
            expect(effect?.label).toBe('Satisfied');
            expect(effect?.tooltip).toBe(formatEffectTooltip(EFFECTS_CONFIG.smokedSausage));
            expect(effect?.tooltip).toContain('+10 Max HP');
            // Never above the real remaining time, which is what makes ceil safe on the client.
            expect(effect?.remainingMs).toBeGreaterThan(24_000);
            expect(effect?.remainingMs).toBeLessThanOrEqual(25_000);
        });

        it('sends no duration at all for a permanent effect', () => {
            const p = makePlayer({ effects: [{ ...EFFECTS_CONFIG.konamiCheat }] });

            expect(buildPlayerSnapshot(p).effects.find(e => e.id === 'konami_cheat')?.remainingMs).toBeUndefined();
        });

        it('builds weapon/armor ItemView with flattened modifiers, undefined when absent', () => {
            const p = makePlayer({ weaponId: 3, armorId: 3 }); // both have modifiers at this tier
            const snapshot = buildPlayerSnapshot(p);

            expect(snapshot.weapon).toMatchObject({ id: 3, crit: 3 });
            expect(snapshot.weapon?.regen).toBeUndefined();
            expect(snapshot.weapon?.maxHealth).toBeUndefined();

            expect(snapshot.armor).toMatchObject({ id: 3, regen: 1 });
            expect(snapshot.armor?.crit).toBeUndefined();
        });

        it('starting weapon/armor (index 0) have no flattened modifiers at all', () => {
            const snapshot = buildPlayerSnapshot(makePlayer());
            expect(snapshot.weapon?.crit).toBeUndefined();
            expect(snapshot.weapon?.regen).toBeUndefined();
            expect(snapshot.weapon?.maxHealth).toBeUndefined();
            expect(snapshot.armor?.crit).toBeUndefined();
            expect(snapshot.armor?.regen).toBeUndefined();
            expect(snapshot.armor?.maxHealth).toBeUndefined();
        });

        it('exposes counters with safe defaults when absent', () => {
            const snapshot = buildPlayerSnapshot(makePlayer());
            expect(snapshot.counters).toEqual({
                totalBattles: 0, totalAmbushes: 0, consecutiveAmbushes: 0, totalEnemiesKilled: 0,
            });
        });

        it('exposes counters as provided', () => {
            const p = makePlayer({ totalBattles: 5, totalAmbushes: 3, consecutiveAmbushes: 1, totalEnemiesKilled: 10 });
            const snapshot = buildPlayerSnapshot(p);
            expect(snapshot.counters).toEqual({
                totalBattles: 5, totalAmbushes: 3, consecutiveAmbushes: 1, totalEnemiesKilled: 10,
            });
        });

        it('is null when the player has never fought (no lastBattleNarrative persisted yet)', () => {
            const snapshot = buildPlayerSnapshot(makePlayer());
            expect(snapshot.lastBattle).toBeNull();
        });

        it('carries the persisted lastBattleNarrative through verbatim (Fix 4 — survives reconnect)', () => {
            const lastBattleNarrative = {
                narrative: {
                    critLine: null, killLine: 'k', deflectionLine: 'd', outcomeLine: 'o',
                    ambushLine: 'Bandits leap from the treeline!', fightPrompt: 'Fight them!', nextMove: 'Strike',
                },
                outcome: { enemiesKilled: 2, hpLost: 8, damageBlocked: 1, xpGained: 20, adenaGained: 6, isCritical: false, isLevelUp: false },
                ambushed: true,
                died: false,
                sound: 'ambush' as const,
            };
            const p = makePlayer({ lastBattleNarrative });
            const snapshot = buildPlayerSnapshot(p);
            expect(snapshot.lastBattle).toEqual(lastBattleNarrative);
        });
    });

    describe('highscoreEligible truth table', () => {
        const cases: Array<{ dead: boolean; coward: boolean; cheated: boolean; expected: boolean }> = [
            { dead: false, coward: false, cheated: false, expected: false },
            { dead: true, coward: false, cheated: false, expected: true },
            { dead: true, coward: true, cheated: false, expected: false },
            { dead: true, coward: false, cheated: true, expected: false },
            { dead: true, coward: true, cheated: true, expected: false },
            { dead: false, coward: true, cheated: false, expected: false },
        ];

        it.each(cases)('dead=$dead coward=$coward cheated=$cheated -> $expected', ({ dead, coward, cheated, expected }) => {
            const p = makePlayer({ dead, coward, cheated });
            const snapshot = buildPlayerSnapshot(p);
            expect(snapshot.highscoreEligible).toBe(expected);
        });
    });
});

describe('toItemView', () => {
    it('flattens crit/regen/maxHealth modifiers, leaving absent ones undefined', () => {
        const view = toItemView(WEAPONS[3]);
        expect(view).toEqual({
            id: 3, name: WEAPONS[3].name, emoji: WEAPONS[3].emoji, stat: WEAPONS[3].stat, cost: WEAPONS[3].cost,
            crit: 3, regen: undefined, maxHealth: undefined,
        });
    });

    it('handles items with no modifiers at all', () => {
        const view = toItemView(ARMORS[0]);
        expect(view.crit).toBeUndefined();
        expect(view.regen).toBeUndefined();
        expect(view.maxHealth).toBeUndefined();
    });
});
