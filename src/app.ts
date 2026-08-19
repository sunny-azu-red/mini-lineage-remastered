import express from 'express';
import path from 'path';
import helmet from 'helmet';
import compression from 'compression';
import staticRouter from '@/route/static.route';
import gameRouter from '@/route/game.route';
import errorRouter from '@/route/error.route';
import { sessionMiddleware } from '@/middleware/session.middleware';
import { lockMiddleware } from '@/middleware/lock.middleware';
import { zoneMiddleware } from '@/middleware/zone.middleware';
import { cheatMiddleware } from '@/middleware/cheat.middleware';
import { flashMiddleware } from '@/middleware/flash.middleware';
import { debugMiddleware } from '@/middleware/debug.middleware';
import { errorMiddleware } from '@/middleware/error.middleware';
import { isRelease } from '@/util/version.util';
import { GAME_VERSION } from '@/constant/game.constant';

const app = express();
const staticPath = isRelease(GAME_VERSION)
    ? path.join(__dirname, 'public')
    : path.join(__dirname, '../public');

app.set('trust proxy', 1);
app.use(helmet());
app.use(compression());
app.use(express.urlencoded({ extended: true }));
app.use('/', staticRouter);
app.use(express.static(staticPath));
app.use(sessionMiddleware);
app.use(lockMiddleware);
app.use(zoneMiddleware);
app.use(debugMiddleware);
app.use(flashMiddleware);
app.use(cheatMiddleware);
app.use('/', gameRouter);
app.use('/', errorRouter);
app.use(errorMiddleware);

export default app;
