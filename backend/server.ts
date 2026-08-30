import 'dotenv/config';
import http from 'http';
import app from './app';
import { env } from '@/config/env.config';
import { GAME_VERSION } from '@/constant/game.constant';
import { initSocketService } from '@/socket';
import { sessionMiddleware } from '@/middleware/session.middleware';

const server = http.createServer(app);
initSocketService(server, sessionMiddleware);

server.listen(env.PORT, () => {
    console.log(`${GAME_VERSION} | Mini-Lineage remastered running on port ${env.PORT}!`);
});
