import { describe, it, expect, vi } from 'vitest';
import { renderHighscoresView } from '@/view/highscores.view';
import { HighscoreEntry, PlayerState } from '@/interface';

vi.mock('@/view/base.view', () => ({
    readTemplate: vi.fn().mockImplementation((name) => ({ content: '', filename: name })),
    render: vi.fn().mockImplementation((tpl, locals) => {
        return JSON.stringify({ tpl: tpl.filename, ...locals });
    })
}));

const makeScore = (overrides: Partial<HighscoreEntry> = {}): HighscoreEntry => ({
    name: 'Legendary Hero',
    race_id: 0,
    level: 50,
    total_xp: 1_000_000,
    adena: 500_000,
    created: '2026-08-15 12:30:00',
    ...overrides,
});

describe('highscores.view', () => {
    it('renders empty highscores list for unstarted player', () => {
        const html = renderHighscoresView([], undefined, null);
        expect(html).toBeDefined();
        expect(html).toContain('isGameStarted');
    });

    it('renders formatted highscore rows and detects active game session', () => {
        const activePlayer: PlayerState = {
            name: 'Seth',
            raceId: 2,
            health: 75,
            adena: 450,
            experience: 0,
            weaponId: 0,
            armorId: 0,
        };

        const score = makeScore({
            name: 'A Very Long Hero Name That Should Be Truncated',
            race_id: 2,
            level: 80,
            total_xp: 50_000_000,
            adena: 9_999_999,
        });

        const html = renderHighscoresView([score], 2, activePlayer);
        expect(html).toBeDefined();
        expect(html).toContain('isGameStarted');
        expect(html).toContain('🧝');
    });

    it('handles unknown race ID gracefully', () => {
        const score = makeScore({ race_id: 999 as any });
        const html = renderHighscoresView([score]);
        expect(html).toBeDefined();
        expect(html).toContain('❓');
    });
});
