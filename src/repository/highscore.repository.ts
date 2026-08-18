import { dbPool } from '@/config/database.config';
import { HighscoreEntry } from '@/interface';
import { HIGHSCORES_CONFIG } from '@/constant/game.constant';

export const highscoreRepository = {
    async insert(data: { name: string; experience: number; raceId: number; adena: number; level: number }): Promise<void> {
        await dbPool.execute(
            'INSERT INTO highscores (name, total_xp, race_id, adena, level, created) VALUES (?, ?, ?, ?, ?, NOW())',
            [data.name, data.experience, data.raceId, data.adena, data.level]
        );
    },

    async findAll(raceId?: number): Promise<HighscoreEntry[]> {
        if (raceId !== undefined) {
            const [rows] = await dbPool.execute(
                `SELECT * FROM highscores WHERE race_id = ? ORDER BY total_xp DESC, adena DESC LIMIT ${HIGHSCORES_CONFIG.limit}`,
                [raceId]
            );
            return rows as HighscoreEntry[];
        }
        const [rows] = await dbPool.execute(`SELECT * FROM highscores ORDER BY total_xp DESC, adena DESC LIMIT ${HIGHSCORES_CONFIG.limit}`);
        return rows as HighscoreEntry[];
    },
};
