import express from 'express';
import path from 'path';
import { isRelease } from '@/util/version.util';
import { GAME_VERSION } from '@/constant/game.constant';

export const getStaticPath = (): string =>
    isRelease(GAME_VERSION)
        ? path.join(__dirname, '../public')
        : path.join(__dirname, '../../public');

export const staticMiddleware = express.static(getStaticPath());
