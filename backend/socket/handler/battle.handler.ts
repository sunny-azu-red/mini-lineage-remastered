import type { Server as SocketIOServer, Socket } from 'socket.io';
import type { BattleFightResult, SoundName } from '@shared/contract';
import { registerEvent } from '../registry';
import { requireStarted, requireAlive } from '../guard';
import { battleLimiter } from '../rate-limit';
import { EmptyPayloadSchema } from '@/schema/socket.schema';
import { simulateBattle } from '@/service/battle.service';
import { getPlayerStats, applyEffect, resolveBattleOutcome, syncZoneAuras } from '@/service/player.service';
import { calculateAmbushChance, calculateLevel } from '@/service/math.service';
import { buildBattleNarrative } from '@/service/narrative.service';
import { formatNumber } from '@/util/format.util';
import { EFFECTS_CONFIG } from '@/constant/game.constant';
import { statisticsRepository } from '@/repository/statistics.repository';
import { buildPlayerSnapshot } from '../serializer/player.serializer';

/**
 * INVARIANT: battle:fight succeeds IDENTICALLY whether or not `ambushed` was already true.
 * An ambush is resolved by fighting again — there is no precondition on `ambushed` and no
 * punishment for navigating away. Combined with hydrate being non-mutating, that makes the
 * old navigate-away-while-ambushed exploit structurally impossible. Simulation runs ONLY
 * from this explicit emit — never on mount, hydrate or reconnect.
 */
export function registerBattleHandlers(io: SocketIOServer, socket: Socket): void {
    registerEvent(io, socket, {
        event: 'battle:fight',
        schema: EmptyPayloadSchema,
        mode: 'mutate',
        guards: [requireStarted, requireAlive],
        rateLimit: battleLimiter,
        handler: (ctx): BattleFightResult => {
            // Stamped directly rather than relying on the separate player:screen event, which is
            // an independent round trip that could land out of order and miscompute the zone.
            ctx.player.ambushed = false;
            ctx.player.currentScreen = 'battle';

            // Not redundant with withSession's post-mutation sync: that runs after this handler
            // returns, but the snapshot below is built now.
            syncZoneAuras(ctx.player);

            const outcome = simulateBattle(ctx.player);
            outcome.isLevelUp = resolveBattleOutcome(ctx.player, outcome);

            const died = Boolean(ctx.player.dead);

            if (!died) {
                const stats = getPlayerStats(ctx.player);
                if (calculateAmbushChance(stats.ambushRisk)) {
                    ctx.player.ambushed = true;
                    ctx.player.totalAmbushes = (ctx.player.totalAmbushes ?? 0) + 1;
                    ctx.player.consecutiveAmbushes = (ctx.player.consecutiveAmbushes ?? 0) + 1;
                    if (ctx.player.consecutiveAmbushes >= 2)
                        applyEffect(ctx.player, EFFECTS_CONFIG.ambushDebuff);

                    void statisticsRepository.increment('total_ambushes');
                } else {
                    ctx.player.consecutiveAmbushes = 0;
                }
                // No re-sync needed: currentScreen === 'battle' already forces combat, so the
                // ambush roll cannot change the zone outcome.
            }

            const ambushed = !died && Boolean(ctx.player.ambushed);
            // Precedence: death > level-up > ambush > crit > silence.
            const sound: SoundName | null = died
                ? 'death'
                : outcome.isLevelUp ? 'level' : ambushed ? 'ambush' : outcome.isCritical ? 'crit' : null;

            const narrative = buildBattleNarrative(ctx.player, outcome, ambushed);

            // Persisted so a reconnect replays this exact narrative instead of a placeholder —
            // same "resolve once, store on PlayerState" pattern as deathReason. `ambushed` here
            // is display text only; PlayerSnapshot.ambushed remains the live source of truth.
            ctx.player.lastBattleNarrative = { narrative, outcome, ambushed, died, sound };

            return {
                player: buildPlayerSnapshot(ctx.player),
                outcome,
                narrative,
                ambushed,
                died,
                flash: !died && outcome.isLevelUp
                    ? { text: `🎉 Congratulations! You have reached level ${formatNumber(calculateLevel(ctx.player.experience))}.`, type: 'warning' as const }
                    : null,
                sound,
            };
        },
    });
}
