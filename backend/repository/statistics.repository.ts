import { dbPool } from '@/config/database.config';
import { Statistics, StatField, StatRow } from '@/interface';
import { ALL_STAT_FIELDS } from '@/constant/statistics.constant';
import { logger } from '@/config/logger.config';

export const statisticsRepository = {
    /**
     * Cannot reject, by design. All 21 call sites are `void`-ed fire-and-forget — `void` silences
     * the linter but attaches no handler, so a rejection here is an UNHANDLED rejection, which
     * terminates the process. A dropped connection mid-fight used to take the whole server down
     * with it. A counter is not worth a crash: log it and carry on.
     */
    async increment(field: StatField, amount: number = 1): Promise<void> {
        try {
            await dbPool.execute(
                'INSERT INTO statistics (name, value) VALUES (?, ?) ON DUPLICATE KEY UPDATE value = value + ?',
                [field, amount, amount]
            );
        } catch (err) {
            logger.error({ err, field, amount }, '📊 Statistics increment failed');
        }
    },

    /** Null when nobody has ever played, so the client can show its empty state. */
    async getAll(): Promise<Statistics | null> {
        const [rows] = await dbPool.execute('SELECT name, value FROM statistics');

        const stats = Object.fromEntries(ALL_STAT_FIELDS.map(field => [field, 0])) as Statistics;
        for (const row of rows as StatRow[]) {
            if (row.name in stats)
                stats[row.name] = Number(row.value);
        }

        return stats.total_players === 0 ? null : stats;
    },
};
