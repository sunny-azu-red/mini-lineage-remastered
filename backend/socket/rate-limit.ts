import { isRelease } from '@/util/version.util';
import { GAME_VERSION, RATE_LIMIT_CONFIG } from '@/constant/game.constant';

/**
 * In-memory sliding-window rate limiter, no external dependency.
 * Mirrors the dev bypass today's rate-limit.middleware.ts applies via `skip: skipIfDev`.
 */
export const skipIfDev = (): boolean => !isRelease(GAME_VERSION);

export interface RateLimiter {
    name: string;
    consume(key: string): { allowed: true } | { allowed: false; retryAfterMs: number };
}

export function createSlidingWindow(name: string, cfg: { windowMs: number; limit: number }): RateLimiter {
    const hits = new Map<string, number[]>();

    const gc = setInterval(() => {
        const now = Date.now();
        for (const [key, timestamps] of hits.entries()) {
            const fresh = timestamps.filter(t => now - t < cfg.windowMs);
            if (fresh.length === 0)
                hits.delete(key);
            else if (fresh.length !== timestamps.length)
                hits.set(key, fresh);
        }
    }, cfg.windowMs);
    gc.unref();

    return {
        name,
        consume(key: string) {
            if (skipIfDev())
                return { allowed: true };

            const now = Date.now();
            const timestamps = (hits.get(key) ?? []).filter(t => now - t < cfg.windowMs);

            if (timestamps.length >= cfg.limit) {
                const oldest = timestamps[0];
                return { allowed: false, retryAfterMs: oldest + cfg.windowMs - now };
            }

            timestamps.push(now);
            hits.set(key, timestamps);

            return { allowed: true };
        },
    };
}

export const battleLimiter = createSlidingWindow('battle', RATE_LIMIT_CONFIG.battle);
export const shopLimiter = createSlidingWindow('shop', RATE_LIMIT_CONFIG.shop);
export const floodLimiter = createSlidingWindow('flood', RATE_LIMIT_CONFIG.flood);
