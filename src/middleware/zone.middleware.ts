import { Request, Response, NextFunction } from 'express';
import { TICK_CONFIG, EFFECTS_CONFIG } from '@/constant/game.constant';
import { isGameStarted } from '@/service/player.service';
import { ActiveEffect } from '@/interface';

export const isPathInZones = (zones: readonly string[], currentPath: string): boolean => {
    return zones.some(pattern => {
        if (pattern.endsWith('/*')) {
            const prefix = pattern.slice(0, -1); // e.g. '/shop/*' -> '/shop/'
            return currentPath.startsWith(prefix) && currentPath.length > prefix.length;
        }
        return currentPath === pattern;
    });
};

/**
 * zoneMiddleware — updates active zone auras in player.effects based on current URL path.
 * This ensures the server tick and stats pipeline know if the player is in a resting or combat zone.
 */
export const zoneMiddleware = (req: Request, res: Response, next: NextFunction) => {
    const player = res.locals.player;
    const isPageRequest = req.headers?.accept?.includes('text/html'); // only update zone on HTML GETs to protect the "Resting" state from background noise.

    if (req.method === 'GET' && isPageRequest && player && isGameStarted(player)) {
        const path = req.path;
        const isResting = isPathInZones(TICK_CONFIG.restingZones, path);
        const inCombat = isPathInZones(TICK_CONFIG.combatZones, path);

        // Filter out existing zone state auras ('resting' and 'combat')
        player.effects = (player.effects ?? []).filter((e: ActiveEffect) => e.id !== 'resting' && e.id !== 'combat');

        if (isResting) {
            player.effects.push({ ...EFFECTS_CONFIG.restingAura });
        } else if (inCombat && !player.dead) {
            player.effects.push({ ...EFFECTS_CONFIG.combatAura });
        }
    }

    next();
};
