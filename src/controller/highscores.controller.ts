import { Request, Response } from 'express';
import { calculateLevel } from '@/service/math.service';
import { renderHighscoresView } from '@/view/highscores.view';
import { highscoreRepository } from '@/repository/highscore.repository';
import { RACES } from '@/constant/game.constant';
import { slugify } from '@/util/format.util';

export const postHighscores = async (req: Request, res: Response) => {
    const player = res.locals.player;
    if (player.dead && !player.coward) {
        const race = RACES.find(r => r.id === player.raceId);
        const redirectUrl = race ? `/highscores/${slugify(race.label)}` : '/highscores';

        await highscoreRepository.insert({
            name: player.name,
            experience: player.experience,
            raceId: player.raceId,
            adena: player.adena,
            level: calculateLevel(player.experience),
        });

        return req.session.destroy(() => {
            res.redirect(redirectUrl);
        });
    }

    res.redirect('/highscores');
};

export const getHighscores = async (req: Request, res: Response) => {
    const { raceLabel } = req.params;
    let filteredRaceId: number | undefined;

    if (raceLabel) {
        const race = RACES.find(r => slugify(r.label) === raceLabel);
        if (race)
            filteredRaceId = race.id;
    }

    const highscores = await highscoreRepository.findAll(filteredRaceId);
    res.send(renderHighscoresView(highscores, filteredRaceId, res.locals.player));
};
