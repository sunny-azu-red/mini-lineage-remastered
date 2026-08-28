import type { Server as SocketIOServer, Socket } from 'socket.io';
import type { HighscoreSubmitResult, HighscoreList } from '@shared/contract';
import { registerEvent } from '../registry';
import { requireStarted, requireDead, requireHighscoreEligible } from '../guard';
import { EmptyPayloadSchema, HighscoreListPayloadSchema } from '@/schema/socket.schema';
import { resetPlayer } from '@/service/player.service';
import { calculateLevel } from '@/service/math.service';
import { slugify } from '@/util/format.util';
import { RACES } from '@/constant/game.constant';
import { highscoreRepository } from '@/repository/highscore.repository';
import { buildPlayerSnapshot } from '../serializer/player.serializer';
import { buildGameCatalog } from '../serializer/catalog.serializer';

/**
 * From highscores.controller.ts's postHighscores/getHighscores.
 */
export function registerHighscoresHandlers(io: SocketIOServer, socket: Socket): void {
    registerEvent(io, socket, {
        event: 'highscores:submit',
        schema: EmptyPayloadSchema,
        mode: 'mutate',
        guards: [requireStarted, requireDead, requireHighscoreEligible],
        handler: async (ctx): Promise<HighscoreSubmitResult> => {
            const race = RACES.find(r => r.id === ctx.player.raceId);

            await highscoreRepository.insert({
                name: ctx.player.name,
                experience: ctx.player.experience,
                raceId: ctx.player.raceId,
                adena: ctx.player.adena,
                level: calculateLevel(ctx.player.experience),
            });

            const raceSlug = race ? slugify(race.label) : null;

            // Plan decision A9: reset in place instead of session.destroy() — destroying
            // mid-socket would leave the socket authenticated against a dead row.
            resetPlayer(ctx.player);

            return {
                raceSlug,
                hydrate: { player: buildPlayerSnapshot(ctx.player), catalog: buildGameCatalog() },
            };
        },
    });

    registerEvent(io, socket, {
        event: 'highscores:list',
        schema: HighscoreListPayloadSchema,
        mode: 'read',
        // Public — works for anyone, matching today's unauthenticated-safe getHighscores.
        handler: async (_ctx, payload): Promise<HighscoreList> => {
            const rows = await highscoreRepository.findAll(payload.raceId ?? undefined);

            return {
                raceId: payload.raceId ?? null,
                rows: rows.map(row => ({
                    name: row.name,
                    raceId: row.race_id,
                    level: row.level,
                    totalXp: row.total_xp,
                    adena: row.adena,
                    created: new Date(row.created).toISOString(),
                })),
            };
        },
    });
}
