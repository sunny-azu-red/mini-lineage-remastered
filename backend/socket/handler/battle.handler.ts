import type { Server as SocketIOServer, Socket } from 'socket.io';
import type { BattleFightResult, MutationResult, SoundName } from '@shared/contract';
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
 * Registers both Battle-screen events: `battle:fight` (from battle.controller.ts's getBattle —
 * the heart of the anti-cheat redesign, plan A6) and `battle:leave` (see its own doc comment
 * below, and syncZoneAuras in player.service.ts).
 *
 * INVARIANT: battle:fight must succeed IDENTICALLY whether or not ctx.player.ambushed was
 * already true when this handler runs. There is no "you must resolve the ambush by leaving"
 * punishment and no precondition on `ambushed` at all — an ambush is resolved by fighting
 * again, full stop. This is what makes the old navigate-away-while-ambushed exploit (and the
 * cheat.middleware.ts mechanism built to punish it) structurally impossible now: viewing or
 * reconnecting is provably non-mutating (see hydrate), and simulateBattle only ever runs from
 * this explicit emit.
 */
export function registerBattleHandlers(io: SocketIOServer, socket: Socket): void {
    registerEvent(io, socket, {
        event: 'battle:fight',
        schema: EmptyPayloadSchema,
        mode: 'mutate',
        guards: [requireStarted, requireAlive],
        rateLimit: battleLimiter,
        handler: (ctx): BattleFightResult => {
            // Unconditionally resolve whatever ambush was pending, then simulate.
            ctx.player.ambushed = false;
            ctx.player.lastFightAt = Date.now();

            // NOT redundant with withSession's own automatic upfront syncZoneAuras call
            // (session.ts): that call ran before this handler started, against the
            // PRE-fight lastFightAt/ambushed — a harmless no-op resync of whatever zone
            // was already true. This call runs AFTER lastFightAt was just bumped above,
            // so it's the one that actually flips the zone into combat for THIS fight.
            syncZoneAuras(ctx.player);

            const results = simulateBattle(ctx.player);
            results.isLevelUp = resolveBattleOutcome(ctx.player, results);

            if (ctx.player.dead) {
                // resolveBattleOutcome -> killPlayer already set deathReason exactly once.
                const deathNarrative = buildBattleNarrative(ctx.player, results, false);

                // Persist so a reconnect (or any later buildPlayerSnapshot()) shows this exact
                // narrative instead of a generic placeholder — mirrors resolveDeathReason()'s
                // "resolve once, persist on PlayerState" pattern.
                ctx.player.lastBattleNarrative = {
                    narrative: deathNarrative,
                    outcome: results,
                    ambushed: false,
                    died: true,
                    sound: 'death',
                };

                return {
                    player: buildPlayerSnapshot(ctx.player),
                    outcome: results,
                    narrative: deathNarrative,
                    ambushed: false,
                    died: true,
                    flash: null,
                    sound: 'death',
                };
            }

            // Roll a fresh ambush chance exactly as battle.controller.ts does today,
            // including the consecutiveAmbushes >= 2 -> ambushDebuff snowball.
            const stats = getPlayerStats(ctx.player);
            const isAmbushed = calculateAmbushChance(stats.ambushRisk);
            if (isAmbushed) {
                ctx.player.ambushed = true;
                ctx.player.totalAmbushes = (ctx.player.totalAmbushes ?? 0) + 1;
                ctx.player.consecutiveAmbushes = (ctx.player.consecutiveAmbushes ?? 0) + 1;
                if (ctx.player.consecutiveAmbushes >= 2)
                    applyEffect(ctx.player, EFFECTS_CONFIG.ambushDebuff);

                void statisticsRepository.increment('total_ambushes');
            } else {
                ctx.player.consecutiveAmbushes = 0;
            }

            // Re-sync: zone (resting/combat) depends on `ambushed`, which may have just
            // flipped true by the roll above — a second, idempotent call keeps the
            // persisted zone state correct rather than one fight stale.
            syncZoneAuras(ctx.player);

            const flash = results.isLevelUp
                ? { text: `🎉 Congratulations! You have reached level ${formatNumber(calculateLevel(ctx.player.experience))}.`, type: 'warning' as const }
                : null;

            // Precedence: level-up (if any) beats ambush beats crit beats none — mirrors
            // battle.controller.ts, which resolves the level-up flash FIRST (and only falls
            // back to res.locals.flash otherwise), and battle.view.ts's own ternary
            // (`flash?.sound ? undefined : (ambushed ? 'ambush' : (isCritical ? 'crit' : undefined))`),
            // which only ever computes an ambush/crit sound when no flash sound (i.e. no
            // level-up) is already set — folded here into one resolved value.
            const sound: SoundName | null = results.isLevelUp
                ? 'level'
                : (ctx.player.ambushed ? 'ambush' : (results.isCritical ? 'crit' : null));

            const narrative = buildBattleNarrative(ctx.player, results, ctx.player.ambushed);

            // Persist so a reconnect (or any later buildPlayerSnapshot()) shows this exact
            // narrative instead of a generic placeholder — mirrors resolveDeathReason()'s
            // "resolve once, persist on PlayerState" pattern. `ambushed` here is the SAME
            // post-roll value already returned below, purely for display text — the live
            // `ctx.player.ambushed`/PlayerSnapshot.ambushed field stays the sole source of truth
            // for whether an ambush is currently active.
            ctx.player.lastBattleNarrative = {
                narrative,
                outcome: results,
                ambushed: Boolean(ctx.player.ambushed),
                died: false,
                sound,
            };

            return {
                player: buildPlayerSnapshot(ctx.player),
                outcome: results,
                narrative,
                ambushed: Boolean(ctx.player.ambushed),
                died: false,
                flash,
                sound,
            };
        },
    });

    registerEvent(io, socket, {
        event: 'battle:leave',
        schema: EmptyPayloadSchema,
        mode: 'mutate',
        guards: [requireStarted, requireAlive],
        handler: (ctx): MutationResult => {
            // Ignored while ambushed: syncZoneAuras already blocks regen unconditionally in
            // that case (`Boolean(player.ambushed) ||` short-circuits before this timestamp is
            // even consulted), and an ambushed player can never reach a screen to send this
            // from anyway (the store pins screen to 'battle' whenever ambushed) — but a raw
            // socket call could still send it, so stamping it here would just be a no-op with
            // a misleading persisted value.
            if (!ctx.player.ambushed)
                ctx.player.battleLeftAt = Date.now();

            // NOT redundant with withSession's own automatic upfront syncZoneAuras call — see
            // battle:fight's identical comment above. This one runs AFTER battleLeftAt was
            // just stamped, so it's the one that actually starts the grace-period countdown.
            syncZoneAuras(ctx.player);

            return { player: buildPlayerSnapshot(ctx.player), flash: null };
        },
    });
}
