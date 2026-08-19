import { dbPool } from '@/config/database.config';
import { Statistics, StatField, StatRow } from '@/interface';
import { ALL_STAT_FIELDS } from '@/constant/statistics.constant';

export const statisticsRepository = {
    async increment(field: StatField, amount: number = 1): Promise<void> {
        await dbPool.execute(
            `INSERT INTO statistics (name, value) VALUES (?, ?) ON DUPLICATE KEY UPDATE value = value + ?`,
            [field, amount, amount]
        );
    },

    async getAll(): Promise<Statistics | null> {
        const [rows] = await dbPool.execute('SELECT name, value FROM statistics');
        const dbRows = rows as StatRow[];

        const stats = ALL_STAT_FIELDS.reduce((acc, field) => { // initialize all stats with 0
            acc[field] = 0;

            return acc;
        }, {} as any) as Statistics;

        dbRows.forEach(row => { // overwrite with actual values from the database
            if (row.name in stats)
                stats[row.name] = Number(row.value);
        });

        if (stats.total_players === 0)
            return null;

        return stats;
    },
};
