import pino from 'pino';
import { GAME_VERSION } from '@/constant/game.constant';
import { isRelease } from '@/util/version.util';

export const logger = pino(
    isRelease(GAME_VERSION)
        ? { level: 'info' }
        : {
            level: 'debug',
            transport: {
                target: 'pino-pretty',
                options: { colorize: true, translateTime: 'SYS:HH:MM:ss' },
            },
        }
);
