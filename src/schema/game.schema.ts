import { z } from 'zod';
import { RACES, CHARACTER_CONFIG } from '@/constant/game.constant';
import { itemIdSchema } from './common.schema';

const RACE_IDS = RACES.map(r => r.id);

export const GameStartSchema = z.object({
    select_race: itemIdSchema(RACE_IDS),
    name: z.string().trim().min(CHARACTER_CONFIG.nameMinLength).max(CHARACTER_CONFIG.nameMaxLength),
});

