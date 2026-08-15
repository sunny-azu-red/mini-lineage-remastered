import { Request, Response, NextFunction } from 'express';
import { TICK_CONFIG } from '@/constant/game.constant';
import { isGameStarted } from '@/service/player.service';

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
 * zoneMiddleware — updates session flags based on the current URL path.
 * This ensures the server tick knows if the player is in a resting or combat zone.
 */
export const zoneMiddleware = (req: Request, res: Response, next: NextFunction) => {
    const player = res.locals.player;
    const isPageRequest = req.headers?.accept?.includes('text/html'); // only update zone on HTML GETs to protect the "Resting" state from background noise.

    if (req.method === 'GET' && isPageRequest && player && isGameStarted(player)) {
        const path = req.path;

        player.isResting = isPathInZones(TICK_CONFIG.restingZones, path);
        player.inCombat = isPathInZones(TICK_CONFIG.combatZones, path);
    }

    next();
};
