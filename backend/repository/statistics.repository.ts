import { dbPool } from '@/config/database.config';
import { Statistics, StatField, StatRow } from '@/interface';
import { ALL_STAT_FIELDS } from '@/constant/statistics.constant';

export const statisticsRepository = {
    async increment(field: StatField, amount: number = 1): Promise<void> {
        await dbPool.execute(
            'INSERT INTO statistics (name, value) VALUES (?, ?) ON DUPLICATE KEY UPDATE value = value + ?',
            [field, amount, amount]
        );
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
