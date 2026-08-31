import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import type { Socket, Server as SocketIOServer } from 'socket.io';
import type { Ack, BattleFightResult, MutationResult, HydratePayload, HighscoreSubmitResult } from '@shared/contract';

/**
 * A full game played end-to-end through the REAL socket stack — registry, guards, session
 * locking, zone auras, battle math, narratives and serializers all unmocked. Only the two things
 * that aren't game logic are stubbed: the session store/lock (our "database") and the repository
 * layer. `Math.random` is driven by a deterministic sequence so every outcome is reproducible.
 *
 * This is the regression net for structural refactors: unit tests pin each module's behaviour,
 * this pins the behaviour of all of them wired together, the way a player actually experiences it.
 */

vi.mock('@/util/lock.util', () => ({ acquireSessionLock: vi.fn() }));
vi.mock('@/util/session-store.util', () => ({ getSessionData: vi.fn(), setSessionData: vi.fn() }));
vi.mock('@/repository/statistics.repository', () => ({
    statisticsRepository: { increment: vi.fn().mockResolvedValue(undefined), getAll: vi.fn() },
}));
vi.mock('@/repository/highscore.repository', () => ({
    highscoreRepository: { insert: vi.fn().mockResolvedValue(undefined), findAll: vi.fn().mockResolvedValue([]) },
}));

import { acquireSessionLock } from '@/util/lock.util';
import { getSessionData, setSessionData } from '@/util/session-store.util';
import { highscoreRepository } from '@/repository/highscore.repository';
import { registerGameHandlers } from '@/socket/handler/game.handler';
import { registerBattleHandlers } from '@/socket/handler/battle.handler';
import { registerShopHandlers } from '@/socket/handler/shop.handler';
import { registerPlayerHandlers } from '@/socket/handler/player.handler';
import { registerHighscoresHandlers } from '@/socket/handler/highscores.handler';
import { registerCheatHandler } from '@/socket/handler/cheat.handler';
import { trackSocket, sessionTracker } from '@/socket/emitter';
import { CHEAT_CONFIG, RACES, WEAPONS, ARMORS, FOODS, ZONE_CONFIG } from '@/constant/game.constant';

const SESSION_ID = 'playthrough-session';

/** A tiny in-memory stand-in for the MySQL-backed session store. */
let store: Record<string, any>;
type Handler = (...args: unknown[]) => Promise<void> | void;
let handlers: Map<string, Handler>;
let io: SocketIOServer;
let socket: Socket;

/** Emits an event through the real registry pipeline and resolves with its ack. */
function emit<T>(event: string, payload: unknown = {}): Promise<Ack<T>> {
    return new Promise(resolve => {
        const handler = handlers.get(event);
        if (!handler)
            throw new Error(`no handler registered for '${event}'`);

        void handler(payload, (response: Ack<T>) => resolve(response));
    });
}

function expectOk<T>(ack: Ack<T>): T {
    if (!ack.ok)
        throw new Error(`expected ok, got ${ack.error.code}: ${ack.error.message}`);

    return ack.data;
}

// A fixed, repeating Math.random sequence — enough spread to exercise crits and ambushes without
// ever being genuinely random.
const SEQUENCE = [0.01, 0.42, 0.77, 0.13, 0.95, 0.58, 0.31, 0.86, 0.05, 0.64];
let seqIndex = 0;

beforeEach(() => {
    store = { cookie: {} };
    handlers = new Map();
    seqIndex = 0;

    vi.spyOn(Math, 'random').mockImplementation(() => SEQUENCE[seqIndex++ % SEQUENCE.length]);

    vi.mocked(acquireSessionLock).mockResolvedValue(() => { });
    vi.mocked(getSessionData).mockImplementation(async () => store);
    vi.mocked(setSessionData).mockImplementation(async (_id, data) => { store = data; });

    io = { sockets: { sockets: new Map() } } as unknown as SocketIOServer;
    socket = {
        id: 'socket-1',
        request: { session: { id: SESSION_ID } },
        on: (event: string, handler: Handler) => { handlers.set(event, handler); },
        emit: vi.fn(),
    } as unknown as Socket;

    sessionTracker.clear();
    trackSocket(io, SESSION_ID, socket.id);

    for (const register of [
        registerGameHandlers, registerBattleHandlers, registerShopHandlers,
        registerPlayerHandlers, registerHighscoresHandlers, registerCheatHandler,
    ])
        register(io, socket);
});

afterEach(() => {
    vi.restoreAllMocks();
    sessionTracker.clear();
});

describe('full playthrough over the real socket stack', () => {
    it('rejects every gameplay action before a character exists', async () => {
        for (const event of ['battle:fight', 'player:suicide', 'player:screen'] as const) {
            const ack = await emit(event, event === 'player:screen' ? { screen: 'home' } : {});
            expect(ack.ok).toBe(false);
            expect(ack.ok === false && ack.error.code).toBe('NOT_STARTED');
        }

        const purchase = await emit('shop:purchase', { type: 'weapon', itemId: 1 });
        expect(purchase.ok).toBe(false);
    });

    it('starts a character with the chosen race\'s stats and a resting aura', async () => {
        const elf = RACES[2];
        const result = expectOk<MutationResult>(await emit('game:start', { raceId: elf.id, name: 'Aria' }));

        expect(result.player.started).toBe(true);
        expect(result.player.name).toBe('Aria');
        expect(result.player.raceLabel).toBe('Elf');
        expect(result.player.adena).toBe(elf.startAdena);
        // Newbie Blessing (+20 max HP) applies at once and the character starts at full health.
        expect(result.player.maxHealth).toBe(elf.startHealth + 20);
        expect(result.player.health).toBe(result.player.maxHealth);
        expect(result.player.level).toBe(1);
        expect(result.flash?.sound).toBe('start');

        const effectIds = result.player.effects.map(e => e.id);
        expect(effectIds).toContain('newbie_blessing');
        expect(effectIds).toContain('resting'); // stamped straight onto 'home'
        expect(result.player.stats).toMatchObject({
            attack: WEAPONS[0].stat,
            defense: ARMORS[0].stat + 2, // tunic + newbie blessing
        });
    });

    it('refuses a second character on the same session', async () => {
        expectOk(await emit('game:start', { raceId: 0, name: 'First' }));

        const second = await emit('game:start', { raceId: 1, name: 'Second' });
        expect(second.ok).toBe(false);
        expect(second.ok === false && second.error.code).toBe('ALREADY_STARTED');
    });

    it('validates the start payload before touching any state', async () => {
        const badRace = await emit('game:start', { raceId: 99, name: 'Ghost' });
        expect(badRace.ok === false && badRace.error.code).toBe('INVALID_PAYLOAD');

        const emptyName = await emit('game:start', { raceId: 0, name: '   ' });
        expect(emptyName.ok === false && emptyName.error.code).toBe('INVALID_PAYLOAD');

        expect(store.raceId).toBeUndefined();
    });

    it('buys equipment, rejects unaffordable and already-owned items, and applies food buffs', async () => {
        expectOk(await emit('game:start', { raceId: 2, name: 'Aria' })); // Elf: 450 adena

        const weapon = expectOk<MutationResult>(await emit('shop:purchase', { type: 'weapon', itemId: 1 }));
        expect(weapon.player.weapon?.id).toBe(1);
        expect(weapon.player.adena).toBe(450 - WEAPONS[1].cost);
        expect(weapon.player.stats?.attack).toBe(WEAPONS[1].stat);
        expect(weapon.flash?.type).toBe('success');
        expect(weapon.flash?.sound).toBe('buy');

        // Re-buying the equipped weapon is a rejected-but-valid purchase: ok ack, danger flash.
        const again = expectOk<MutationResult>(await emit('shop:purchase', { type: 'weapon', itemId: 1 }));
        expect(again.flash?.type).toBe('danger');
        expect(again.player.adena).toBe(weapon.player.adena); // no double charge

        const tooExpensive = expectOk<MutationResult>(await emit('shop:purchase', { type: 'armor', itemId: 5 }));
        expect(tooExpensive.flash?.type).toBe('danger');
        expect(tooExpensive.player.armor?.id).toBe(0);

        // The starting items are never purchasable.
        const fists = await emit('shop:purchase', { type: 'weapon', itemId: 0 });
        expect(fists.ok === false && fists.error.code).toBe('INVALID_PAYLOAD');

        const food = expectOk<MutationResult>(await emit('shop:purchase', { type: 'food', itemId: 2 }));
        expect(food.flash?.sound).toBe('eat');
        expect(food.player.effects.map(e => e.id)).toContain('satisfied');
        // The Satisfied buff raises max HP on top of the newbie blessing.
        expect(food.player.maxHealth).toBe(RACES[2].startHealth + 20 + 10);
    });

    it('fights: gains xp and adena, records counters, and narrates the result', async () => {
        expectOk(await emit('game:start', { raceId: 1, name: 'Grok' })); // Orc: 150 hp, tanky

        const before = store.health;
        const fight = expectOk<BattleFightResult>(await emit('battle:fight'));

        expect(fight.died).toBe(false);
        expect(fight.outcome.enemiesKilled).toBeGreaterThan(0);
        expect(fight.outcome.xpGained).toBeGreaterThan(0);
        expect(fight.player.experience).toBe(fight.outcome.xpGained);
        expect(fight.player.health).toBe(before - fight.outcome.hpLost);
        expect(fight.player.counters.totalBattles).toBe(1);
        expect(fight.player.counters.totalEnemiesKilled).toBe(fight.outcome.enemiesKilled);

        // Narrative is fully composed and names the Orc's configured enemy (Humans).
        expect(fight.narrative.killLine).toContain('🧙');
        expect(fight.narrative.deflectionLine).toContain('Damage');
        expect(fight.narrative.nextMove).toBeTruthy();

        // Fighting puts the player in combat, which suspends the resting aura.
        const effectIds = fight.player.effects.map(e => e.id);
        expect(effectIds).toContain('combat');
        expect(effectIds).not.toContain('resting');

        // The narrative is persisted, so a reconnect replays it rather than a placeholder.
        expect(store.lastBattleNarrative.narrative.killLine).toBe(fight.narrative.killLine);
    });

    it('levels up, restores full health, and flashes the new level', async () => {
        expectOk(await emit('game:start', { raceId: 1, name: 'Grok' }));

        let levelUp: BattleFightResult | null = null;
        for (let i = 0; i < 40 && !levelUp; i++) {
            const fight = expectOk<BattleFightResult>(await emit('battle:fight'));
            if (fight.died)
                break;
            if (fight.outcome.isLevelUp)
                levelUp = fight;
            // Keep the Orc alive long enough to reach level 2.
            if (fight.player.health !== null && fight.player.maxHealth !== null && fight.player.health < fight.player.maxHealth / 2)
                store.health = fight.player.maxHealth;
        }

        expect(levelUp).not.toBeNull();
        expect(levelUp!.player.level).toBe(2);
        expect(levelUp!.player.health).toBe(levelUp!.player.maxHealth); // level-up heals to full
        expect(levelUp!.sound).toBe('level');
        expect(levelUp!.flash?.text).toContain('level 2');
    });

    it('dies when HP runs out, then only allows the post-death actions', async () => {
        expectOk(await emit('game:start', { raceId: 2, name: 'Aria' })); // Elf: frailest

        let death: BattleFightResult | null = null;
        for (let i = 0; i < 60 && !death; i++) {
            store.health = 1; // walk into every fight on the brink
            const fight = expectOk<BattleFightResult>(await emit('battle:fight'));
            if (fight.died)
                death = fight;
        }

        expect(death).not.toBeNull();
        expect(death!.player.dead).toBe(true);
        expect(death!.player.health).toBe(0);
        expect(death!.sound).toBe('death');
        expect(death!.player.deathReason).toBeTruthy();
        expect(death!.player.effects).toEqual([]); // death clears every effect
        expect(death!.player.highscoreEligible).toBe(true);

        // The death reason is fixed once and never re-randomized.
        const reason = death!.player.deathReason;
        expectOk(await emit('player:screen', { screen: 'death' }));
        expect(store.deathReason).toBe(reason);

        for (const event of ['battle:fight', 'player:suicide'] as const) {
            const ack = await emit(event);
            expect(ack.ok === false && ack.error.code).toBe('DEAD');
        }
    });

    it('marks a suicide as cowardly and bars it from the highscores', async () => {
        expectOk(await emit('game:start', { raceId: 0, name: 'Quitter' }));

        const suicide = expectOk<MutationResult>(await emit('player:suicide'));
        expect(suicide.player.dead).toBe(true);
        expect(suicide.player.coward).toBe(true);
        expect(suicide.player.deathReason).toContain('cowardly');
        expect(suicide.player.highscoreEligible).toBe(false);

        const submit = await emit('highscores:submit');
        expect(submit.ok === false && submit.error.code).toBe('INELIGIBLE');
        expect(highscoreRepository.insert).not.toHaveBeenCalled();
    });

    it('submits a legitimate death to the highscores and resets the character', async () => {
        expectOk(await emit('game:start', { raceId: 3, name: 'Nyx' }));
        expectOk<BattleFightResult>(await emit('battle:fight'));

        const experience = store.experience;
        const adena = store.adena;
        store.health = 0;
        store.dead = true;

        const result = expectOk<HighscoreSubmitResult>(await emit('highscores:submit'));

        expect(highscoreRepository.insert).toHaveBeenCalledWith(
            expect.objectContaining({ name: 'Nyx', raceId: 3, experience, adena, level: 1 }),
        );
        expect(result.raceSlug).toBe('dark-elf');
        // Submitting resets in place, so the session is immediately ready for a new character.
        expect(result.hydrate.player?.started).toBe(false);
        expect(store.name).toBeUndefined();
        expect(store.lastBattleNarrative).toBeUndefined();
    });

    it('refuses to restart a living character', async () => {
        expectOk(await emit('game:start', { raceId: 0, name: 'Alive' }));

        const restart = await emit('game:restart');

        expect(restart.ok).toBe(false);
        expect(restart.ok === false && restart.error.code).toBe('NOT_DEAD');
        expect(store.name).toBe('Alive');
    });

    it('restarts into a clean slate that can immediately start again', async () => {
        expectOk(await emit('game:start', { raceId: 0, name: 'Old' }));
        expectOk<BattleFightResult>(await emit('battle:fight'));
        store.dead = true; // only the fallen may start over

        const restart = expectOk<{ hydrate: HydratePayload }>(await emit('game:restart'));
        expect(restart.hydrate.player?.started).toBe(false);
        expect(restart.hydrate.catalog.races).toHaveLength(RACES.length);
        expect(store.experience).toBeUndefined();

        const fresh = expectOk<MutationResult>(await emit('game:start', { raceId: 1, name: 'New' }));
        expect(fresh.player.name).toBe('New');
        expect(fresh.player.counters.totalBattles).toBe(0);
    });

    it('classifies zone auras from the reported screen, and never lets an ambush escape combat', async () => {
        expectOk(await emit('game:start', { raceId: 0, name: 'Wanderer' }));

        const inn = expectOk<MutationResult>(await emit('player:screen', { screen: 'inn' }));
        expect(inn.player.effects.map(e => e.id)).toContain('resting');

        const battle = expectOk<MutationResult>(await emit('player:screen', { screen: 'battle' }));
        expect(battle.player.effects.map(e => e.id)).toContain('combat');
        // Standing in the zone: indefinite combat, no countdown.
        expect(battle.player.effects.find(e => e.id === 'combat')?.remainingMs).toBeUndefined();

        // Leaving a combat zone keeps the player flagged for combatLingerMs, wherever they went —
        // Statistics is in neither zone list, but the disengage countdown outranks that.
        const stats = expectOk<MutationResult>(await emit('player:screen', { screen: 'statistics' }));
        const statsIds = stats.player.effects.map(e => e.id);
        expect(statsIds).not.toContain('resting');
        expect(statsIds).toContain('combat');
        // A duration, not the deadline: the wire never sends a server timestamp for the client to
        // compare against its own clock.
        expect(stats.player.effects.find(e => e.id === 'combat')?.remainingMs).toBeLessThanOrEqual(ZONE_CONFIG.combatLingerMs);

        // Once it elapses, a screen in neither zone list gets no aura at all.
        store.combatUntil = Date.now() - 1;
        store.effects = store.effects.map((e: any) => (e.id === 'combat' ? { ...e, expiresAt: Date.now() - 1 } : e));
        const settled = expectOk<MutationResult>(await emit('player:screen', { screen: 'statistics' }));
        const settledIds = settled.player.effects.map(e => e.id);
        expect(settledIds).not.toContain('resting');
        expect(settledIds).not.toContain('combat');

        // An ambushed player who claims to be resting in the Inn is still forced into combat.
        store.ambushed = true;
        const lying = expectOk<MutationResult>(await emit('player:screen', { screen: 'inn' }));
        expect(lying.player.effects.map(e => e.id)).toContain('combat');
        expect(lying.player.ambushed).toBe(true);
    });

    it('resolves an ambush by fighting again, with no penalty for having navigated away', async () => {
        expectOk(await emit('game:start', { raceId: 0, name: 'Wanderer' }));

        store.ambushed = true;
        store.health = 500; // survive the fight regardless of the roll
        store.currentScreen = 'inn'; // "navigated away" mid-ambush

        const fight = expectOk<BattleFightResult>(await emit('battle:fight'));

        expect(fight.died).toBe(false);
        expect(fight.outcome.xpGained).toBeGreaterThan(0);
        // The pending ambush is cleared by fighting; only a fresh roll can set it again.
        expect(store.currentScreen).toBe('battle');
    });

    it('activates the Konami cheat, which marks the player and bars the highscores', async () => {
        expectOk(await emit('game:start', { raceId: 0, name: 'Cheater' }));
        store.health = 10;

        const input = handlers.get('input')!;
        for (const key of CHEAT_CONFIG.konamiSequence)
            await input({ key: key.toUpperCase() }); // case-insensitive

        expect(store.cheated).toBe(true);
        expect(store.effects.map((e: { id: string }) => e.id)).toContain('konami_cheat');
        expect(store.health).toBeGreaterThan(10); // snapped back to the boosted max

        store.dead = true;
        const submit = await emit('highscores:submit');
        expect(submit.ok === false && submit.error.code).toBe('INELIGIBLE');
    });

    it('ignores a wrong Konami sequence', async () => {
        expectOk(await emit('game:start', { raceId: 0, name: 'Honest' }));

        const input = handlers.get('input')!;
        for (const key of ['a', 'b', 'a', 'b', 'a', 'b', 'a', 'b', 'a', 'b'])
            await input({ key });

        expect(store.cheated).toBeUndefined();
    });

    it('lists highscores without a character, since the board is public', async () => {
        vi.mocked(highscoreRepository.findAll).mockResolvedValueOnce([
            { name: 'Legend', race_id: 0, total_xp: 9999, adena: 500, level: 7, created: '2026-01-01T00:00:00Z' },
        ] as never);

        const list = expectOk<{ rows: { name: string }[] }>(await emit('highscores:list', { raceId: null }));
        expect(list.rows[0].name).toBe('Legend');
    });

    it('keeps every purchasable catalog item affordable in the order the shops list them', async () => {
        // Guards the scaling curve: each tier must cost strictly more than the one before it.
        for (const items of [WEAPONS, ARMORS, FOODS]) {
            const costs = items.map(i => i.cost);
            expect([...costs].sort((a, b) => a - b)).toEqual(costs);
        }
    });
});
