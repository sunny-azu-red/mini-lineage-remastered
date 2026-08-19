import fs from 'fs';
import path from 'path';
import { Router } from 'express';
import { getSharedConfig } from '@/util/config.util';
import { isRelease } from '@/util/version.util';
import { GAME_VERSION } from '@/constant/game.constant';

const router = Router();

/**
 * Dynamic Init & Config
 * Serves the shared game constants and sidebar initialization to the frontend.
 * This is public and doesn't require session/locking.
 */
router.get('/js/init.js', (req, res) => {
    const initPath = path.resolve(process.cwd(), 'public/js/init.js');
    const initCode = fs.existsSync(initPath) ? fs.readFileSync(initPath, 'utf-8') : '';
    let js = `window.CONFIG = ${JSON.stringify(getSharedConfig())};\n${initCode}`;

    if (isRelease(GAME_VERSION))
        js = js
            .replace(/\/\/.*$/gm, '')
            .replace(/\/\*[\s\S]*?\*\//g, '')
            .replace(/\s+/g, ' ')
            .trim();

    res.type('application/javascript').send(js);
});

export default router;
