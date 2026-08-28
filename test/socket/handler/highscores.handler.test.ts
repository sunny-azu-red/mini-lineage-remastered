import { describe, it, expect, vi, beforeEach } from 'vitest';
import type { Socket, Server as SocketIOServer } from 'socket.io';

vi.mock('@/socket/registry', () => ({ registerEvent: vi.fn() }));
vi.mock('@/repository/highscore.repository', () => ({
    highscoreRepository: {
        insert: vi.fn().mockResolvedValue(undefined),
        findAll: vi.fn().mockResolvedValue([]),
    },
}));

import { registerEvent } from '@/socket/registry';
import { registerHighscoresHandlers } from '@/socket/handler/highscores.handler';
import { requireStarted, requireDead, requireHighscoreEligible } from '@/socket/guard';
import { highscoreRepository } from '@/repository/highscore.repository';
import type { SessionContext } from '@/socket/session';
import type { PlayerState, HighscoreEntry } from '@/interface';

function getDef(event: string) {
    const call = vi.mocked(registerEvent).mock.calls.find(c => (c[2] as any).event === event);
    if (!call)
        throw new Error(`${event} not registered`);

    return call[2] as any;
}

function makeCtx(overrides: Partial<PlayerState> = {}): SessionContext {
    const player = {
        name: 'Hero', raceId: 0, health: 0, adena: 500, experience: 1000,
        weaponId: 0, armorId: 0, dead: true, ...overrides,
    } as PlayerState;

    return { sessionId: 'sid-1', session: {}, player };
}

describe('highscores.handler', () => {
    const io = {} as SocketIOServer;
    const socket = {} as Socket;

    beforeEach(() => {
        vi.clearAllMocks();
        registerHighscoresHandlers(io, socket);
    });

    describe('highscores:submit', () => {
        it('guards requireStarted/requireDead/requireHighscoreEligible', () => {
            const def = getDef('highscores:submit');
            expect(def.guards).toEqual([requireStarted, requireDead, requireHighscoreEligible]);
            expect(def.mode).toBe('mutate');
        });

        it('inserts the row, resets the player in place, and returns raceSlug + a fresh hydrate', async () => {
            const ctx = makeCtx({ raceId: 0, name: 'Hero', experience: 1000, adena: 500 });
            const result = await getDef('highscores:submit').handler(ctx);

            expect(highscoreRepository.insert).toHaveBeenCalledWith({
                name: 'Hero', experience: 1000, raceId: 0, adena: 500, level: expect.any(Number),
            });
            expect(result.raceSlug).toBe('human');
            expect(ctx.player.name).toBeUndefined(); // reset in place
            expect(result.hydrate.player.started).toBe(false);
        });

        it('resolves raceSlug to null if the race cannot be resolved', async () => {
            const ctx = makeCtx({ raceId: 999 as any });
            const result = await getDef('highscores:submit').handler(ctx);
            expect(result.raceSlug).toBeNull();
        });
    });

    describe('highscores:list', () => {
        it('is a public read with no guards', () => {
            const def = getDef('highscores:list');
            expect(def.mode).toBe('read');
            expect(def.guards).toBeUndefined();
        });

        it('maps repository rows to 1-based ranked HighscoreRow entries', async () => {
            const rows: HighscoreEntry[] = [
                { name: 'A', race_id: 0, total_xp: 500, adena: 100, level: 5, created: '2024-01-01T00:00:00.000Z' },
                { name: 'B', race_id: 0, total_xp: 300, adena: 50, level: 3, created: '2024-01-02T00:00:00.000Z' },
            ];
            vi.mocked(highscoreRepository.findAll).mockResolvedValue(rows);

            const result = await getDef('highscores:list').handler(makeCtx(), { raceId: 0 });

            expect(highscoreRepository.findAll).toHaveBeenCalledWith(0);
            expect(result.raceId).toBe(0);
            expect(result.rows).toEqual([
                { rank: 1, name: 'A', raceId: 0, level: 5, totalXp: 500, adena: 100, created: '2024-01-01T00:00:00.000Z' },
                { rank: 2, name: 'B', raceId: 0, level: 3, totalXp: 300, adena: 50, created: '2024-01-02T00:00:00.000Z' },
            ]);
        });

        it('passes undefined to findAll (all races) and null raceId in the response when omitted', async () => {
            vi.mocked(highscoreRepository.findAll).mockResolvedValue([]);
            const result = await getDef('highscores:list').handler(makeCtx(), {});

            expect(highscoreRepository.findAll).toHaveBeenCalledWith(undefined);
            expect(result.raceId).toBeNull();
        });
    });
});
