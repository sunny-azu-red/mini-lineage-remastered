import { describe, it, expect, vi } from 'vitest';
import { zoneMiddleware, isPathInZones } from './zone.middleware';
import { TICK_CONFIG } from '@/constant/game.constant';
import * as playerService from '@/service/player.service';

vi.mock('@/service/player.service', () => ({
    isGameStarted: vi.fn()
}));

describe('isPathInZones', () => {
    const zones = ['/', '/inn', '/shop/*', '/character', '/highscores', '/highscores/*'];

    it('matches exact paths correctly', () => {
        expect(isPathInZones(zones, '/')).toBe(true);
        expect(isPathInZones(zones, '/inn')).toBe(true);
        expect(isPathInZones(zones, '/character')).toBe(true);
        expect(isPathInZones(zones, '/highscores')).toBe(true);
        expect(isPathInZones(zones, '/inn/lol')).toBe(false);
        expect(isPathInZones(zones, '/character/extra')).toBe(false);
    });

    it('matches wildcard sub-paths and rejects false prefixes', () => {
        expect(isPathInZones(zones, '/shop/weapons')).toBe(true);
        expect(isPathInZones(zones, '/shop/armors')).toBe(true);
        expect(isPathInZones(zones, '/shop')).toBe(false);
        expect(isPathInZones(zones, '/shopping')).toBe(false);

        expect(isPathInZones(zones, '/highscores/human')).toBe(true);
        expect(isPathInZones(zones, '/highscores/orc')).toBe(true);
    });

    it('returns false for unmatched paths', () => {
        expect(isPathInZones(zones, '/battle')).toBe(false);
        expect(isPathInZones(zones, '/unknown')).toBe(false);
    });
});

describe('zoneMiddleware', () => {
    it('should set isResting to true if path is in restingZones', () => {
        const player = { isResting: false, inCombat: false };
        const req = { method: 'GET', path: '/', headers: { accept: 'text/html' } };
        const res = { locals: { player } };
        const next = vi.fn();

        vi.mocked(playerService.isGameStarted).mockReturnValue(true);

        zoneMiddleware(req as any, res as any, next);

        expect(player.isResting).toBe(true);
        expect(player.inCombat).toBe(false);
        expect(next).toHaveBeenCalled();
    });

    it('should set isResting to true for wildcard paths like /shop/weapons and /highscores/human', () => {
        const player = { isResting: false, inCombat: false };
        const req = { method: 'GET', path: '/shop/weapons', headers: { accept: 'text/html' } };
        const res = { locals: { player } };
        const next = vi.fn();

        vi.mocked(playerService.isGameStarted).mockReturnValue(true);

        zoneMiddleware(req as any, res as any, next);

        expect(player.isResting).toBe(true);
        expect(player.inCombat).toBe(false);

        const req2 = { method: 'GET', path: '/highscores/human', headers: { accept: 'text/html' } };
        zoneMiddleware(req2 as any, res as any, next);
        expect(player.isResting).toBe(true);
    });

    it('should not set isResting to true for invalid subpaths of exact zones', () => {
        const player = { isResting: false, inCombat: false };
        const req = { method: 'GET', path: '/inn/invalid-subpath', headers: { accept: 'text/html' } };
        const res = { locals: { player } };
        const next = vi.fn();

        vi.mocked(playerService.isGameStarted).mockReturnValue(true);

        zoneMiddleware(req as any, res as any, next);

        expect(player.isResting).toBe(false);
        expect(player.inCombat).toBe(false);
        expect(next).toHaveBeenCalled();
    });

    it('should set inCombat to true if path is in combatZones', () => {
        const player = { isResting: false, inCombat: false };
        const req = { method: 'GET', path: '/battle', headers: { accept: 'text/html' } };
        const res = { locals: { player } };
        const next = vi.fn();

        vi.mocked(playerService.isGameStarted).mockReturnValue(true);

        zoneMiddleware(req as any, res as any, next);

        expect(player.isResting).toBe(false);
        expect(player.inCombat).toBe(true);
        expect(next).toHaveBeenCalled();
    });

    it('should do nothing if method is not GET', () => {
        const player = { isResting: false, inCombat: false };
        const req = { method: 'POST', path: '/' };
        const res = { locals: { player } };
        const next = vi.fn();

        vi.mocked(playerService.isGameStarted).mockReturnValue(true);

        zoneMiddleware(req as any, res as any, next);

        expect(player.isResting).toBe(false);
        expect(player.inCombat).toBe(false);
        expect(next).toHaveBeenCalled();
    });

    it('should do nothing if game is not started', () => {
        const player = { isResting: false, inCombat: false };
        const req = { method: 'GET', path: '/' };
        const res = { locals: { player } };
        const next = vi.fn();

        vi.mocked(playerService.isGameStarted).mockReturnValue(false);

        zoneMiddleware(req as any, res as any, next);

        expect(player.isResting).toBe(false);
        expect(player.inCombat).toBe(false);
        expect(next).toHaveBeenCalled();
    });

    it('should handle missing player gracefully', () => {
        const req = { method: 'GET', path: '/' };
        const res = { locals: {} };
        const next = vi.fn();

        zoneMiddleware(req as any, res as any, next);

        expect(next).toHaveBeenCalled();
    });
    it('should do nothing if Accept header does not include text/html', () => {
        const player = { isResting: true, inCombat: false };
        const req = { method: 'GET', path: '/battle', headers: { accept: 'application/json' } };
        const res = { locals: { player } };
        const next = vi.fn();

        vi.mocked(playerService.isGameStarted).mockReturnValue(true);

        zoneMiddleware(req as any, res as any, next);

        // Should NOT change from true to false because it's not an HTML request
        expect(player.isResting).toBe(true);
        expect(next).toHaveBeenCalled();
    });
});
