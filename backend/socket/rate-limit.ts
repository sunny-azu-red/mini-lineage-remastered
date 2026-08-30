import { isRelease } from '@/util/version.util';
import { GAME_VERSION, RATE_LIMIT_CONFIG } from '@/constant/game.constant';

/** Rate limiting is bypassed entirely outside a release build. */
export const skipIfDev = (): boolean => !isRelease(GAME_VERSION);

export interface RateLimiter {
    name: string;
    consume(key: string): { allowed: true } | { allowed: false; retryAfterMs: number };
}

/** In-memory sliding window, no external dependency. */
export function createSlidingWindow(name: string, cfg: { windowMs: number; limit: number }): RateLimiter {
    const hits = new Map<string, number[]>();
    const fresh = (timestamps: number[], now: number) => timestamps.filter(t => now - t < cfg.windowMs);

    const gc = setInterval(() => {
        const now = Date.now();
        for (const [key, timestamps] of hits.entries()) {
            const kept = fresh(timestamps, now);
            if (kept.length === 0)
                hits.delete(key);
            else if (kept.length !== timestamps.length)
                hits.set(key, kept);
        }
    }, cfg.windowMs);
    gc.unref();

    return {
        name,
        consume(key: string) {
            if (skipIfDev())
                return { allowed: true };

            const now = Date.now();
            const timestamps = fresh(hits.get(key) ?? [], now);

            if (timestamps.length >= cfg.limit)
                return { allowed: false, retryAfterMs: timestamps[0] + cfg.windowMs - now };

            timestamps.push(now);
            hits.set(key, timestamps);

            return { allowed: true };
        },
    };
}

export const battleLimiter = createSlidingWindow('battle', RATE_LIMIT_CONFIG.battle);
export const shopLimiter = createSlidingWindow('shop', RATE_LIMIT_CONFIG.shop);
export const floodLimiter = createSlidingWindow('flood', RATE_LIMIT_CONFIG.flood);
