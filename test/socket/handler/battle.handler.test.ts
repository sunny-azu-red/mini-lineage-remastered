import { describe, it, expect, vi, beforeEach } from 'vitest';
import type { Socket, Server as SocketIOServer } from 'socket.io';
import fs from 'fs';
import path from 'path';

vi.mock('@/socket/registry', () => ({ registerEvent: vi.fn() }));

vi.mock('@/service/battle.service', () => ({
    simulateBattle: vi.fn(),
}));

vi.mock('@/repository/statistics.repository', () => ({
    statisticsRepository: { increment: vi.fn().mockResolvedValue(undefined) },
}));

vi.mock('@/service/math.service', async (importOriginal) => {
    const actual = await importOriginal<typeof import('@/service/math.service')>();
    return { ...actual, calculateAmbushChance: vi.fn() };
});

import { registerEvent } from '@/socket/registry';
import { registerBattleHandlers } from '@/socket/handler/battle.handler';
import { requireStarted, requireAlive } from '@/socket/guard';
import { battleLimiter } from '@/socket/rate-limit';
import { simulateBattle } from '@/service/battle.service';
import * as mathService from '@/service/math.service';
import { statisticsRepository } from '@/repository/statistics.repository';
import { resolveDeathReason } from '@/service/player.service';
import { EFFECTS_CONFIG } from '@/constant/game.constant';
import type { SessionContext } from '@/socket/session';
import type { PlayerState, BattleResult } from '@/interface';

function getDef() {
    const call = vi.mocked(registerEvent).mock.calls.find(c => (c[2] as any).event === 'battle:fight');
    if (!call)
        throw new Error('battle:fight not registered');

    return call[2] as any;
}

function makePlayer(overrides: Partial<PlayerState> = {}): PlayerState {
    return {
        name: 'Hero',
        raceId: 0,
        health: 100,
        adena: 100,
        experience: 0,
        weaponId: 0,
        armorId: 0,
        dead: false,
        ambushed: false,
        ...overrides,
    } as PlayerState;
}

function makeCtx(player: PlayerState): SessionContext {
    return { sessionId: 'sid-1', session: {}, player, zoneChanged: false };
}

function makeBattleResult(overrides: Partial<BattleResult> = {}): BattleResult {
    return {
        enemiesKilled: 3,
        hpLost: 5,
        damageBlocked: 2,
        xpGained: 10,
        adenaGained: 5,
        isCritical: false,
        isLevelUp: false,
        ...overrides,
    };
}

describe('battle.handler', () => {
    const io = {} as SocketIOServer;
    const socket = {} as Socket;

    beforeEach(() => {
        vi.clearAllMocks();
        vi.mocked(mathService.calculateAmbushChance).mockReturnValue(false);
        registerBattleHandlers(io, socket);
    });

    it('guards requireStarted/requireAlive and rate-limits with battleLimiter', () => {
        const def = getDef();
        expect(def.guards).toEqual([requireStarted, requireAlive]);
        expect(def.rateLimit).toBe(battleLimiter);
    });

    describe('the core anti-cheat invariant', () => {
        it('succeeds identically whether ambushed starts true or false', () => {
            vi.mocked(simulateBattle).mockReturnValue(makeBattleResult());

            const ctxTrue = makeCtx(makePlayer({ ambushed: true }));
            const ctxFalse = makeCtx(makePlayer({ ambushed: false }));

            expect(() => getDef().handler(ctxTrue)).not.toThrow();
            expect(() => getDef().handler(ctxFalse)).not.toThrow();
        });

        it('clears ambushed before simulating (simulateBattle never sees ambushed:true)', () => {
            vi.mocked(simulateBattle).mockImplementation((p: any) => {
                expect(p.ambushed).toBe(false);
                return makeBattleResult();
            });

            getDef().handler(makeCtx(makePlayer({ ambushed: true })));
            expect(simulateBattle).toHaveBeenCalled();
        });

        it('may re-set ambushed after simulating, based on a fresh roll', () => {
            vi.mocked(simulateBattle).mockReturnValue(makeBattleResult());
            vi.mocked(mathService.calculateAmbushChance).mockReturnValue(true);

            const ctx = makeCtx(makePlayer({ ambushed: true }));
            const result = getDef().handler(ctx);

            expect(ctx.player.ambushed).toBe(true);
            expect(result.ambushed).toBe(true);
            expect(statisticsRepository.increment).toHaveBeenCalledWith('total_ambushes');
        });
    });

    describe('the death path', () => {
        it('sets deathReason exactly once and returns died:true with sound "death"', () => {
            vi.mocked(simulateBattle).mockReturnValue(makeBattleResult({ hpLost: 1000 }));

            const ctx = makeCtx(makePlayer({ health: 10 }));
            const result = getDef().handler(ctx);

            expect(ctx.player.dead).toBe(true);
            expect(ctx.player.deathReason).toBeTruthy();
            expect(result.died).toBe(true);
            expect(result.ambushed).toBe(false);
            expect(result.flash).toBeNull();
            expect(result.sound).toBe('death');

            const reasonAfterFirstDeath = ctx.player.deathReason;
            resolveDeathReason(ctx.player); // idempotent — must not re-randomize
            expect(ctx.player.deathReason).toBe(reasonAfterFirstDeath);
        });

        it('does not roll a fresh ambush chance once dead', () => {
            vi.mocked(simulateBattle).mockReturnValue(makeBattleResult({ hpLost: 1000 }));
            getDef().handler(makeCtx(makePlayer({ health: 1 })));
            expect(mathService.calculateAmbushChance).not.toHaveBeenCalled();
        });
    });

    describe('consecutive ambush snowball', () => {
        it('applies the Hexed debuff once consecutiveAmbushes reaches 2', () => {
            vi.mocked(simulateBattle).mockReturnValue(makeBattleResult());
            vi.mocked(mathService.calculateAmbushChance).mockReturnValue(true);

            const ctx = makeCtx(makePlayer({ consecutiveAmbushes: 1 }));
            getDef().handler(ctx);

            expect(ctx.player.consecutiveAmbushes).toBe(2);
            expect(ctx.player.effects?.some(e => e.id === EFFECTS_CONFIG.ambushDebuff.id)).toBe(true);
        });

        it('resets consecutiveAmbushes to 0 when not ambushed', () => {
            vi.mocked(simulateBattle).mockReturnValue(makeBattleResult());
            vi.mocked(mathService.calculateAmbushChance).mockReturnValue(false);

            const ctx = makeCtx(makePlayer({ consecutiveAmbushes: 3 }));
            getDef().handler(ctx);

            expect(ctx.player.consecutiveAmbushes).toBe(0);
        });
    });

    describe('sound/flash precedence: level beats ambush beats crit beats none', () => {
        it('resolves "level" and a congratulatory flash on level-up, even while ambushed+critical', () => {
            vi.mocked(simulateBattle).mockReturnValue(makeBattleResult({ xpGained: 780, isCritical: true }));
            vi.mocked(mathService.calculateAmbushChance).mockReturnValue(true);

            const ctx = makeCtx(makePlayer({ experience: 0 }));
            const result = getDef().handler(ctx);

            expect(result.outcome.isLevelUp).toBe(true);
            expect(result.sound).toBe('level');
            expect(result.flash).toMatchObject({ type: 'warning' });
            expect(result.flash!.text).toContain('level');
        });

        it('resolves "ambush" over "crit" when both apply but no level-up', () => {
            vi.mocked(simulateBattle).mockReturnValue(makeBattleResult({ isCritical: true }));
            vi.mocked(mathService.calculateAmbushChance).mockReturnValue(true);

            const result = getDef().handler(makeCtx(makePlayer()));

            expect(result.sound).toBe('ambush');
            expect(result.flash).toBeNull();
        });

        it('resolves "crit" when critical but not ambushed or leveled', () => {
            vi.mocked(simulateBattle).mockReturnValue(makeBattleResult({ isCritical: true }));
            vi.mocked(mathService.calculateAmbushChance).mockReturnValue(false);

            const result = getDef().handler(makeCtx(makePlayer()));

            expect(result.sound).toBe('crit');
        });

        it('resolves null when nothing special happened', () => {
            vi.mocked(simulateBattle).mockReturnValue(makeBattleResult({ isCritical: false }));
            vi.mocked(mathService.calculateAmbushChance).mockReturnValue(false);

            const result = getDef().handler(makeCtx(makePlayer()));

            expect(result.sound).toBeNull();
            expect(result.flash).toBeNull();
        });
    });

    describe('persisting lastBattleNarrative (Fix 4 — survives reconnect)', () => {
        it('writes ctx.player.lastBattleNarrative matching the ack narrative/outcome/sound exactly, on a live (non-death) fight', () => {
            vi.mocked(simulateBattle).mockReturnValue(makeBattleResult({ isCritical: true }));
            vi.mocked(mathService.calculateAmbushChance).mockReturnValue(true);

            const ctx = makeCtx(makePlayer());
            const result = getDef().handler(ctx);

            expect(ctx.player.lastBattleNarrative).toEqual({
                narrative: result.narrative,
                outcome: result.outcome,
                ambushed: result.ambushed,
                died: result.died,
                sound: result.sound,
            });
            expect(ctx.player.lastBattleNarrative?.ambushed).toBe(true);
            expect(ctx.player.lastBattleNarrative?.died).toBe(false);
        });

        it('writes ctx.player.lastBattleNarrative matching the ack on the death path too', () => {
            vi.mocked(simulateBattle).mockReturnValue(makeBattleResult({ hpLost: 1000 }));

            const ctx = makeCtx(makePlayer({ health: 10 }));
            const result = getDef().handler(ctx);

            expect(result.died).toBe(true);
            expect(ctx.player.lastBattleNarrative).toEqual({
                narrative: result.narrative,
                outcome: result.outcome,
                ambushed: result.ambushed,
                died: result.died,
                sound: result.sound,
            });
            expect(ctx.player.lastBattleNarrative?.died).toBe(true);
            expect(ctx.player.lastBattleNarrative?.sound).toBe('death');
        });

        it('the persisted narrative rides along in the ack\'s own player snapshot (buildPlayerSnapshot runs after the write)', () => {
            vi.mocked(simulateBattle).mockReturnValue(makeBattleResult());
            vi.mocked(mathService.calculateAmbushChance).mockReturnValue(false);

            const ctx = makeCtx(makePlayer());
            const result = getDef().handler(ctx);

            expect((result.player as any).lastBattle).toEqual(ctx.player.lastBattleNarrative);
        });
    });

    it('hydrate/connect wiring never references simulateBattle (structural regression guard)', () => {
        const indexSrc = fs.readFileSync(path.join(__dirname, '..', '..', '..', 'src', 'socket', 'index.ts'), 'utf8');
        expect(indexSrc).not.toContain('simulateBattle');
    });
});
