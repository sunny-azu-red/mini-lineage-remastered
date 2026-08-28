import { describe, it, expect } from 'vitest';
import {
    requireStarted,
    requireNotStarted,
    requireAlive,
    requireDead,
    requireNotAmbushed,
    requireHighscoreEligible,
} from '@/socket/guard';
import { SocketError } from '@/socket/error';
import { PlayerState } from '@/interface';

const startedPlayer = (overrides: Partial<PlayerState> = {}): PlayerState => ({
    name: 'Hero',
    raceId: 0,
    health: 100,
    adena: 100,
    experience: 0,
    weaponId: 0,
    armorId: 0,
    ...overrides,
} as PlayerState);

describe('requireStarted', () => {
    it('passes for a started player', () => {
        expect(() => requireStarted(startedPlayer())).not.toThrow();
    });

    it('throws NOT_STARTED for a fresh, uninitialized player', () => {
        expect(() => requireStarted({} as PlayerState)).toThrow(SocketError);
        try {
            requireStarted({} as PlayerState);
        } catch (err) {
            expect((err as SocketError).code).toBe('NOT_STARTED');
        }
    });
});

describe('requireNotStarted', () => {
    it('passes for an uninitialized player', () => {
        expect(() => requireNotStarted({} as PlayerState)).not.toThrow();
    });

    it('throws ALREADY_STARTED for a started player', () => {
        try {
            requireNotStarted(startedPlayer());
            expect.unreachable();
        } catch (err) {
            expect((err as SocketError).code).toBe('ALREADY_STARTED');
        }
    });
});

describe('requireAlive', () => {
    it('passes for a living player', () => {
        expect(() => requireAlive(startedPlayer({ dead: false }))).not.toThrow();
    });

    it('throws DEAD for a dead player', () => {
        try {
            requireAlive(startedPlayer({ dead: true }));
            expect.unreachable();
        } catch (err) {
            expect((err as SocketError).code).toBe('DEAD');
        }
    });
});

describe('requireDead', () => {
    it('passes for a dead player', () => {
        expect(() => requireDead(startedPlayer({ dead: true }))).not.toThrow();
    });

    it('throws NOT_DEAD for a living player', () => {
        try {
            requireDead(startedPlayer({ dead: false }));
            expect.unreachable();
        } catch (err) {
            expect((err as SocketError).code).toBe('NOT_DEAD');
        }
    });
});

describe('requireNotAmbushed', () => {
    it('passes when not ambushed', () => {
        expect(() => requireNotAmbushed(startedPlayer({ ambushed: false }))).not.toThrow();
    });

    it('throws AMBUSHED when ambushed', () => {
        try {
            requireNotAmbushed(startedPlayer({ ambushed: true }));
            expect.unreachable();
        } catch (err) {
            expect((err as SocketError).code).toBe('AMBUSHED');
        }
    });
});

describe('requireHighscoreEligible', () => {
    it('passes for a player who is neither coward nor cheated', () => {
        expect(() => requireHighscoreEligible(startedPlayer())).not.toThrow();
    });

    it('throws INELIGIBLE for a coward', () => {
        try {
            requireHighscoreEligible(startedPlayer({ coward: true }));
            expect.unreachable();
        } catch (err) {
            expect((err as SocketError).code).toBe('INELIGIBLE');
        }
    });

    it('throws INELIGIBLE for a cheater', () => {
        try {
            requireHighscoreEligible(startedPlayer({ cheated: true }));
            expect.unreachable();
        } catch (err) {
            expect((err as SocketError).code).toBe('INELIGIBLE');
        }
    });
});
