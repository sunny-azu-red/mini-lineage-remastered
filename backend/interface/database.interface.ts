import { RaceType } from './game.interface';

export interface HighscoreEntry {
    name: string;
    race_id: RaceType;
    total_xp: number;
    adena: number;
    level: number;
    created: string;
}
