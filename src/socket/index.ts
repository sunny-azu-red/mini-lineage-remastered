import type { Server as HttpServer } from 'http';
import { Server as SocketIOServer, Socket } from 'socket.io';
import type { RequestHandler } from 'express';
import type { PlayerState } from '@/interface';
import { getSessionData } from '@/util/session-store.util';
import { logger } from '@/config/logger.config';
import { trackSocket, untrackSocket, emitHydrate, syncExpiryTimers, sessionTracker } from './emitter';
import { startTickLoop, processSessionTick } from './tick';
import { buildPlayerSnapshot } from './serializer/player.serializer';
import { buildGameCatalog } from './serializer/catalog.serializer';
import { registerGameHandlers } from './handler/game.handler';
import { registerBattleHandlers } from './handler/battle.handler';
import { registerShopHandlers } from './handler/shop.handler';
import { registerPlayerHandlers } from './handler/player.handler';
import { registerHighscoresHandlers } from './handler/highscores.handler';
import { registerStatisticsHandlers } from './handler/statistics.handler';
import { registerCheatHandler } from './handler/cheat.handler';

/**
 * Initializes the NEW socket-driven API this phase introduces. Runs entirely side-by-side
 * with today's legacy `src/service/socket.service.ts` server — neither is modified nor
 * shares any state with the other (separate sessionTracker Map instances, separate event
 * names/contract).
 *
 * Collision avoidance: this server is mounted on a DISTINCT Engine.IO path,
 * `/socket.io/v2`, rather than the default `/socket.io` the legacy server already owns.
 * A Socket.IO *namespace* (e.g. `io.of('/v2')`) would NOT have been sufficient here — a
 * namespace still shares the underlying Engine.IO handshake/path with whatever server first
 * attached to it, and the legacy server has already claimed the default path outright. Two
 * independent `new SocketIOServer(server, { path })` instances on distinct paths are the
 * simplest way to guarantee zero interference. A later "demolition" phase deletes the legacy
 * server and moves this one onto the default path.
 */
export function initNewSocketService(server: HttpServer, sessionMiddleware: RequestHandler): SocketIOServer {
    const io = new SocketIOServer(server, {
        path: '/socket.io/v2',
        cors: { origin: false },
    });

    io.use((socket, next) => {
        (sessionMiddleware as any)(socket.request, {}, next);
    });

    io.on('connection', (socket: Socket) => {
        const req = socket.request as any;
        const sessionId: string | undefined = req.session?.id;

        if (sessionId) {
            trackSocket(io, sessionId, socket.id);

            // Hydrate is provably non-mutating — read whatever's in the store (or nothing)
            // and send it as-is. This is what makes even a mid-ambush hard refresh harmless.
            void (async () => {
                try {
                    const session = await getSessionData(sessionId);
                    const player = (session ?? {}) as PlayerState;

                    const tracker = sessionTracker.get(sessionId);
                    if (tracker) {
                        syncExpiryTimers(io, tracker, sessionId, player, (expiredSessionId) => {
                            const activeTracker = sessionTracker.get(expiredSessionId);
                            if (activeTracker)
                                void processSessionTick(io, activeTracker, expiredSessionId, { applyRegen: false });
                        });
                    }

                    emitHydrate(io, sessionId, { player: buildPlayerSnapshot(player), catalog: buildGameCatalog() });
                } catch (err) {
                    logger.error({ err }, '[SOCKET:v2] failed to build hydrate payload on connect');
                }
            })();
        }

        socket.on('disconnect', () => {
            if (sessionId)
                untrackSocket(sessionId, socket.id);
        });

        registerGameHandlers(io, socket);
        registerBattleHandlers(io, socket);
        registerShopHandlers(io, socket);
        registerPlayerHandlers(io, socket);
        registerHighscoresHandlers(io, socket);
        registerStatisticsHandlers(io, socket);
        registerCheatHandler(io, socket);
    });

    startTickLoop(io);

    return io;
}
