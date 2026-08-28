import type { Server as SocketIOServer, Socket } from 'socket.io';
import { SocketInputEventSchema } from '@/schema/socket.schema';
import { CHEAT_CONFIG, EFFECTS_CONFIG } from '@/constant/game.constant';
import { isGameStarted, applyEffect, getPlayerStats } from '@/service/player.service';
import { statisticsRepository } from '@/repository/statistics.repository';
import { withSession, NO_CHANGE } from '../session';
import { floodLimiter } from '../rate-limit';
import { sessionTracker, emitNotice } from '../emitter';
import { logger } from '@/config/logger.config';
import { formatSessionId } from '@/util/format.util';

/**
 * Konami-code relay — ported logic-for-logic from today's socket.service.ts, relocated
 * onto withSession(). `input` has no ack (fire-and-forget), so every failure path (bad
 * payload, no session, flood-limited, not-yet-started/dead player) is a silent no-op —
 * there is nobody to report an error to, exactly like today.
 *
 * The input buffer lives on the per-tracker SessionTrackerEntry (not the session/player
 * data), so this handler reaches into emitter.ts's sessionTracker directly rather than
 * going through the generic SessionContext alone. Buffer bookkeeping intentionally stays
 * OUTSIDE any session lock/store round-trip (matching today's behavior) — only a full
 * Konami match ever touches the session store.
 */
export function registerCheatHandler(io: SocketIOServer, socket: Socket): void {
    socket.on('input', async (payload: unknown) => {
        const req = socket.request as any;
        const sessionId: string | undefined = req.session?.id;
        if (!sessionId)
            return;

        if (!floodLimiter.consume(sessionId).allowed)
            return;

        const parsed = SocketInputEventSchema.safeParse(payload);
        if (!parsed.success)
            return;

        const tracker = sessionTracker.get(sessionId);
        if (!tracker)
            return;

        if (!tracker.inputBuffer)
            tracker.inputBuffer = [];

        tracker.inputBuffer.push(parsed.data.key.toLowerCase());
        if (tracker.inputBuffer.length > CHEAT_CONFIG.konamiSequence.length)
            tracker.inputBuffer.shift();

        const matched = tracker.inputBuffer.length === CHEAT_CONFIG.konamiSequence.length &&
            tracker.inputBuffer.every((k, idx) => k === CHEAT_CONFIG.konamiSequence[idx]);

        if (!matched)
            return;

        tracker.inputBuffer = [];

        try {
            const cheated = await withSession(sessionId, (ctx) => {
                if (!isGameStarted(ctx.player) || ctx.player.dead)
                    return NO_CHANGE;

                ctx.player.cheated = true;
                applyEffect(ctx.player, EFFECTS_CONFIG.konamiCheat);
                ctx.player.health = getPlayerStats(ctx.player).maxHealth;
                void statisticsRepository.increment('total_players_cheated');

                return true;
            });

            if (cheated)
                emitNotice(io, sessionId, { text: "👾 Cheater's Mark applied!", type: 'info' });
        } catch (err) {
            logger.debug({ err }, `[SOCKET:${formatSessionId(sessionId)}] input handler error`);
        }
    });
}
