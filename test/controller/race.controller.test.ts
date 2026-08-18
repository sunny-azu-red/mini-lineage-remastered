import { describe, it, expect, vi } from 'vitest';
import { getRaces } from '@/controller/race.controller';
import * as raceView from '@/view/race.view';

vi.mock('@/view/race.view', () => ({
    renderRacesView: vi.fn(),
}));

describe('raceController', () => {
    it('should render the races view', () => {
        const req = {} as any;
        const res = {
            locals: { player: { id: 1 } },
            send: vi.fn(),
        } as any;

        vi.mocked(raceView.renderRacesView).mockReturnValue('rendered-view');

        getRaces(req, res);

        expect(raceView.renderRacesView).toHaveBeenCalledWith(res.locals.player);
        expect(res.send).toHaveBeenCalledWith('rendered-view');
    });
});
