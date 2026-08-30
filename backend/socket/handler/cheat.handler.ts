import type { Server as SocketIOServer, Socket } from 'socket.io';
import type { PlayerState } from '@/interface';
import { SocketInputEventSchema } from '@/schema/socket.schema';
import { CHEAT_CONFIG, EFFECTS_CONFIG } from '@/constant/game.constant';
import { isGameStarted, applyEffect, getPlayerStats } from '@/service/player.service';
import { statisticsRepository } from '@/repository/statistics.repository';
import { withSession, NO_CHANGE } from '../session';
import { floodLimiter } from '../rate-limit';
import { sessionTracker, emitStateUpdate } from '../emitter';
import { buildPlayerSnapshot } from '../serializer/player.serializer';
import { logger } from '@/config/logger.config';
import { formatSessionId } from '@/util/format.util';

/**
 * Konami-code relay. `input` has no ack, so every failure path is a silent no-op. The key
 * buffer lives on the tracker (not session data) and is kept OUTSIDE any lock/store round trip —
 * only a full match ever touches the session store. Activation is silent by design: no flash,
 * just the debuff icon and HP snapping to full via a normal state push. This handler bypasses
 * registry.ts entirely, so that push is the only thing that reaches the client.
 */
export function registerCheatHandler(io: SocketIOServer, socket: Socket): void {
    socket.on('input', async (payload: unknown) => {
        const sessionId: string | undefined = (socket.request as any).session?.id;
        if (!sessionId || !floodLimiter.consume(sessionId).allowed)
            return;

        const parsed = SocketInputEventSchema.safeParse(payload);
        const tracker = sessionTracker.get(sessionId);
        if (!parsed.success || !tracker)
            return;

        const buffer = tracker.inputBuffer ??= [];
        buffer.push(parsed.data.key.toLowerCase());
        if (buffer.length > CHEAT_CONFIG.konamiSequence.length)
            buffer.shift();

        if (buffer.length !== CHEAT_CONFIG.konamiSequence.length || !buffer.every((k, i) => k === CHEAT_CONFIG.konamiSequence[i]))
            return;

        tracker.inputBuffer = [];

        try {
            let mutatedPlayer: PlayerState | undefined;
            const cheated = await withSession(sessionId, (ctx) => {
                if (!isGameStarted(ctx.player) || ctx.player.dead)
                    return NO_CHANGE;

                ctx.player.cheated = true;
                applyEffect(ctx.player, EFFECTS_CONFIG.konamiCheat);
                ctx.player.health = getPlayerStats(ctx.player).maxHealth;
                void statisticsRepository.increment('total_players_cheated');
                mutatedPlayer = ctx.player;

                return true;
            });

            if (cheated && mutatedPlayer)
                emitStateUpdate(io, sessionId, buildPlayerSnapshot(mutatedPlayer));
        } catch (err) {
            logger.debug({ err }, `[SOCKET:${formatSessionId(sessionId)}] input handler error`);
        }
    });
}
