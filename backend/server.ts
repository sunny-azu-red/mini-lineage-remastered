import 'dotenv/config';
import http from 'http';
import app from './app';
import { env } from '@/config/env.config';
import { GAME_VERSION } from '@/constant/game.constant';
import { initSocketService } from '@/socket';
import { sessionMiddleware } from '@/middleware/session.middleware';
import { statisticsRepository } from '@/repository/statistics.repository';

const server = http.createServer(app);
initSocketService(server, sessionMiddleware);

server.listen(env.PORT, () => {
    console.log(`${GAME_VERSION} | Mini-Lineage remastered running on port ${env.PORT}!`);
});

// Docker stops the container with SIGTERM: drain the buffered counters before the process goes.
function shutdown(): void {
    server.close();
    void statisticsRepository.flush().finally(() => process.exit(0));
}

process.once('SIGTERM', shutdown);
process.once('SIGINT', shutdown);
