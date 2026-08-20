import express from 'express';
import compression from 'compression';
import gameRouter from '@/route/game.route';
import errorRouter from '@/route/error.route';
import { helmetMiddleware } from '@/middleware/helmet.middleware';
import { contextMiddleware } from '@/middleware/context.middleware';
import { staticMiddleware } from '@/middleware/static.middleware';
import { sessionMiddleware } from '@/middleware/session.middleware';
import { lockMiddleware } from '@/middleware/lock.middleware';
import { zoneMiddleware } from '@/middleware/zone.middleware';
import { cheatMiddleware } from '@/middleware/cheat.middleware';
import { flashMiddleware } from '@/middleware/flash.middleware';
import { debugMiddleware } from '@/middleware/debug.middleware';
import { errorMiddleware } from '@/middleware/error.middleware';

const app = express();

app.set('trust proxy', 1);
app.use(contextMiddleware);
app.use(helmetMiddleware);
app.use(compression());
app.use(express.urlencoded({ extended: true }));
app.use(staticMiddleware);
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
