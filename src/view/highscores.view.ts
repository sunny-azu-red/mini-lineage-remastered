import { readTemplate, render } from './base.view';
import { renderSimplePage } from './layout.view';
import { formatAdena, formatNumber, slugify, truncate } from '@/util/format.util';
import { RACES } from '@/constant/game.constant';
import { HighscoreEntry, PlayerState } from '@/interface';
import { isGameStarted } from '@/service/player.service';

const highscoresTpl = readTemplate('highscores.ejs');

export function renderHighscoresView(highscores: HighscoreEntry[] = [], activeRaceId?: number, player: PlayerState | null = null): string {
    const rows = highscores.map((score) => {
        const d = new Date(score.created);
        const pad = (n: number) => n.toString().padStart(2, '0');
        const date = `${pad(d.getDate())}/${pad(d.getMonth() + 1)}/${d.getFullYear().toString().slice(-2)}, ${pad(d.getHours())}:${pad(d.getMinutes())}`;
        const emoji = RACES[score.race_id]?.emoji || '❓';

        return {
            name: `${emoji} ${truncate(score.name, 20)}`,
            level: formatNumber(score.level),
            totalXp: formatNumber(score.total_xp),
            adena: formatAdena(score.adena),
            date,
        };
    });
    const isStarted = player ? isGameStarted(player) : false;
    const content = render(highscoresTpl, { rows, activeRaceId, races: RACES, slugify, isGameStarted: isStarted });

    return renderSimplePage('Hall of Champions', content, null, player);
}
