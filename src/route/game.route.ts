import { Router } from 'express';
import { getHome, postGameStart } from '@/controller/game.controller';
import { getWeaponsShop, postWeaponsShop, getArmorsShop, postArmorsShop, getInn, postInn } from '@/controller/shop.controller';
import { getBattle } from '@/controller/battle.controller';
import { getSuicide, postSuicide, getDeath, getRestart, getCharacter } from '@/controller/player.controller';
import { postHighscores, getHighscores } from '@/controller/highscores.controller';
import { getStatistics } from '@/controller/statistics.controller';
import { getRaces } from '@/controller/race.controller';
import { battleRateLimiter, shopRateLimiter } from '@/middleware/rate-limit.middleware';

const router = Router();

// home & start
router.get('/', getHome);
router.post('/start', postGameStart);

// battle
router.get('/battle', battleRateLimiter, getBattle);

// shops & inn
router.get('/shop/weapons', getWeaponsShop);
router.post('/shop/weapons', shopRateLimiter, postWeaponsShop);
router.get('/shop/armors', getArmorsShop);
router.post('/shop/armors', shopRateLimiter, postArmorsShop);
router.get('/inn', getInn);
router.post('/inn', shopRateLimiter, postInn);

// suicide
router.get('/suicide', getSuicide);
router.post('/suicide', postSuicide);

// death & restart
router.get('/death', getDeath);
router.get('/restart', getRestart);

// character
router.get('/character', getCharacter);

// highscores
router.post('/highscores', postHighscores);
router.get('/highscores', getHighscores);
router.get('/highscores/:raceLabel', getHighscores);

// statistics & races
router.get('/statistics', getStatistics);
router.get('/races', getRaces);

// test error simulation
router.get('/simulate-error', (req, res, next) => {
    next(new Error('💥 This is a simulated system error to test error.ejs!'));
});

export default router;
