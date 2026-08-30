import { dbPool } from '@/config/database.config';
import { HighscoreEntry } from '@/interface';
import { HIGHSCORES_CONFIG } from '@/constant/game.constant';

const ORDER = `ORDER BY total_xp DESC, adena DESC LIMIT ${HIGHSCORES_CONFIG.limit}`;

export const highscoreRepository = {
    async insert(data: { name: string; experience: number; raceId: number; adena: number; level: number }): Promise<void> {
        await dbPool.execute(
            'INSERT INTO highscores (name, total_xp, race_id, adena, level, created) VALUES (?, ?, ?, ?, ?, NOW())',
            [data.name, data.experience, data.raceId, data.adena, data.level]
        );
    },

    async findAll(raceId?: number): Promise<HighscoreEntry[]> {
        const [rows] = raceId !== undefined
            ? await dbPool.execute(`SELECT * FROM highscores WHERE race_id = ? ${ORDER}`, [raceId])
            : await dbPool.execute(`SELECT * FROM highscores ${ORDER}`);

        return rows as HighscoreEntry[];
    },
};
