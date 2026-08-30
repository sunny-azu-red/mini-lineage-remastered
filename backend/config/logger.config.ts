import pino from 'pino';
import { GAME_VERSION } from '@/constant/game.constant';
import { isRelease } from '@/util/version.util';

// A release build raises the level to 'info', which drops every .debug() call.
export const logger = pino(
    isRelease(GAME_VERSION)
        ? { level: 'info' }
        : {
            level: 'debug',
            transport: { target: 'pino-pretty', options: { colorize: true, translateTime: 'SYS:HH:MM:ss' } },
        }
);
