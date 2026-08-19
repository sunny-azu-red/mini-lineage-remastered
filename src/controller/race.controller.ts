import { Request, Response } from 'express';
import { renderRacesView } from '@/view/race.view';

export const getRaces = (req: Request, res: Response) => {
    const player = res.locals.player;

    res.send(renderRacesView(player));
};
