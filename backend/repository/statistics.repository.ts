import { dbPool } from '@/config/database.config';
import { Statistics, StatField, StatRow } from '@/interface';
import { ALL_STAT_FIELDS } from '@/constant/statistics.constant';
import { logger } from '@/config/logger.config';

// Counters land here and reach the database in one batched statement per flush, instead of one
// round-trip per counter per fight. Keyed by field, so the buffer is bounded by ALL_STAT_FIELDS.
const pending = new Map<StatField, number>();

export const statisticsRepository = {
    /** Deliberately synchronous: with no promise to drop, a call site cannot leak a rejection. */
    increment(field: StatField, amount: number = 1): void {
        pending.set(field, (pending.get(field) ?? 0) + amount);
    },

    /**
     * Drains the buffer into a single statement. Never rejects — a counter is not worth crashing
     * the tick loop, and taking the batch before awaiting means a concurrent flush finds nothing.
     */
    async flush(): Promise<void> {
        if (pending.size === 0)
            return;

        const batch = [...pending];
        pending.clear();

        try {
            await dbPool.execute(
                `INSERT INTO statistics (name, value) VALUES ${batch.map(() => '(?, ?)').join(', ')} ` +
                'ON DUPLICATE KEY UPDATE value = value + VALUES(value)',
                batch.flat()
            );
        } catch (err) {
            // Re-queued, not dropped: merging back by field keeps the buffer bounded however long
            // the outage lasts, and collapses the log to one line per flush rather than per counter.
            for (const [field, amount] of batch)
                pending.set(field, (pending.get(field) ?? 0) + amount);

            logger.error({ err, counters: batch.length }, '📊 Statistics flush failed, counters re-queued');
        }
    },

    /** Null when nobody has ever played, so the client can show its empty state. */
    async getAll(): Promise<Statistics | null> {
        // Read-your-writes: a brand-new player's own total_players must not still be buffered here,
        // or the archives read as empty to the very player who just filled them.
        await statisticsRepository.flush();

        const [rows] = await dbPool.execute('SELECT name, value FROM statistics');

        const stats = Object.fromEntries(ALL_STAT_FIELDS.map(field => [field, 0])) as Statistics;
        for (const row of rows as StatRow[]) {
            if (row.name in stats)
                stats[row.name] = Number(row.value);
        }

        return stats.total_players === 0 ? null : stats;
    },
};
