import { describe, it, expect, vi } from 'vitest';
import { zoneMiddleware, isPathInZones } from './zone.middleware';
import { REGEN_CONFIG, EFFECTS_CONFIG } from '@/constant/game.constant';
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
    it('should add resting aura to effects if path is in restingZones', () => {
        const player: any = { effects: [] };
        const req = { method: 'GET', path: '/', headers: { accept: 'text/html' } };
        const res = { locals: { player } };
        const next = vi.fn();

        vi.mocked(playerService.isGameStarted).mockReturnValue(true);

        zoneMiddleware(req as any, res as any, next);

        expect(player.effects.some((e: any) => e.id === 'resting')).toBe(true);
        expect(player.effects.some((e: any) => e.id === 'combat')).toBe(false);
        expect(next).toHaveBeenCalled();
    });

    it('should add resting aura to effects for wildcard paths like /shop/weapons and /highscores/human', () => {
        const player: any = { effects: [] };
        const req = { method: 'GET', path: '/shop/weapons', headers: { accept: 'text/html' } };
        const res = { locals: { player } };
        const next = vi.fn();

        vi.mocked(playerService.isGameStarted).mockReturnValue(true);

        zoneMiddleware(req as any, res as any, next);

        expect(player.effects.some((e: any) => e.id === 'resting')).toBe(true);
        expect(player.effects.some((e: any) => e.id === 'combat')).toBe(false);

        const req2 = { method: 'GET', path: '/highscores/human', headers: { accept: 'text/html' } };
        zoneMiddleware(req2 as any, res as any, next);
        expect(player.effects.some((e: any) => e.id === 'resting')).toBe(true);
    });

    it('should not add resting aura for invalid subpaths of exact zones', () => {
        const player: any = { effects: [] };
        const req = { method: 'GET', path: '/inn/invalid-subpath', headers: { accept: 'text/html' } };
        const res = { locals: { player } };
        const next = vi.fn();

        vi.mocked(playerService.isGameStarted).mockReturnValue(true);

        zoneMiddleware(req as any, res as any, next);

        expect(player.effects.some((e: any) => e.id === 'resting')).toBe(false);
        expect(player.effects.some((e: any) => e.id === 'combat')).toBe(false);
        expect(next).toHaveBeenCalled();
    });

    it('should add combat aura to effects if path is in combatZones', () => {
        const player: any = { effects: [] };
        const req = { method: 'GET', path: '/battle', headers: { accept: 'text/html' } };
        const res = { locals: { player } };
        const next = vi.fn();

        vi.mocked(playerService.isGameStarted).mockReturnValue(true);

        zoneMiddleware(req as any, res as any, next);

        expect(player.effects.some((e: any) => e.id === 'resting')).toBe(false);
        expect(player.effects.some((e: any) => e.id === 'combat')).toBe(true);
        expect(next).toHaveBeenCalled();
    });

    it('should do nothing if method is not GET', () => {
        const player: any = { effects: [] };
        const req = { method: 'POST', path: '/' };
        const res = { locals: { player } };
        const next = vi.fn();

        vi.mocked(playerService.isGameStarted).mockReturnValue(true);

        zoneMiddleware(req as any, res as any, next);

        expect(player.effects.length).toBe(0);
        expect(next).toHaveBeenCalled();
    });

    it('should do nothing if game is not started', () => {
        const player: any = { effects: [] };
        const req = { method: 'GET', path: '/' };
        const res = { locals: { player } };
        const next = vi.fn();

        vi.mocked(playerService.isGameStarted).mockReturnValue(false);

        zoneMiddleware(req as any, res as any, next);

        expect(player.effects.length).toBe(0);
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
        const player: any = {
            effects: [{ ...EFFECTS_CONFIG.restingAura }]
        };
        const req = { method: 'GET', path: '/battle', headers: { accept: 'application/json' } };
        const res = { locals: { player } };
        const next = vi.fn();

        vi.mocked(playerService.isGameStarted).mockReturnValue(true);

        zoneMiddleware(req as any, res as any, next);

        // Should NOT change because it's not an HTML request
        expect(player.effects.some((e: any) => e.id === 'resting')).toBe(true);
        expect(next).toHaveBeenCalled();
    });
});
