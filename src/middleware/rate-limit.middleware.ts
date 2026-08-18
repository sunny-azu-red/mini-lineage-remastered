import rateLimit from 'express-rate-limit';
import { renderRateLimitView } from '@/view/rate-limit.view';
import { isRelease } from '@/util/version.util';
import { GAME_VERSION, RATE_LIMIT_CONFIG } from '@/constant/game.constant';

export const skipIfDev = () => !isRelease(GAME_VERSION);

export const battleRateLimitHandler = (req: any, res: any) => {
    const player = res.locals.player;
    const isAmbushed = player?.ambushed && !player?.dead;

    const message = isAmbushed
        ? "You are in the middle of an ambush and moving too fast. Please wait a moment before your next move."
        : "You are moving too fast. Please take a breath and try again in a moment.";

    res.status(429).send(renderRateLimitView(player, message, req.originalUrl));
};

export const shopRateLimitHandler = (req: any, res: any) => {
    const player = res.locals.player;
    const message = "You are moving too fast. Please take a breath and try again in a moment.";

    res.status(429).send(renderRateLimitView(player, message, req.originalUrl));
};

export const battleRateLimiter = rateLimit({
    windowMs: RATE_LIMIT_CONFIG.battle.windowMs,
    limit: RATE_LIMIT_CONFIG.battle.limit,
    standardHeaders: 'draft-7',
    legacyHeaders: false,
    skip: skipIfDev,
    handler: battleRateLimitHandler
});

export const shopRateLimiter = rateLimit({
    windowMs: RATE_LIMIT_CONFIG.shop.windowMs,
    limit: RATE_LIMIT_CONFIG.shop.limit,
    standardHeaders: 'draft-7',
    legacyHeaders: false,
    skip: skipIfDev,
    handler: shopRateLimitHandler
});
