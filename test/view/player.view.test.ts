import { describe, it, expect, vi } from 'vitest';
import { renderDeathView, renderSuicideView, renderCharacterView } from '@/view/player.view';
import { renderPage, renderSimplePage } from '@/view/layout.view';
import { PlayerState } from '@/interface';

vi.mock('@/view/base.view', () => ({
    readTemplate: vi.fn().mockImplementation((name) => ({ content: '', filename: name })),
    render: vi.fn().mockImplementation((tpl, locals) => {
        // Return a string that includes key indicators from locals
        return JSON.stringify({ tpl: tpl.filename, ...locals });
    })
}));

const makePlayer = (overrides: Partial<PlayerState> = {}): PlayerState => ({
    name: 'Test Hero',
    raceId: 0,
    health: 100,
    adena: 0,
    experience: 0,
    weaponId: 0,
    armorId: 0,
    dead: false,
    ambushed: false,
    ...overrides,
} as PlayerState);

describe('layout.view', () => {
    it('renders low health alert when health is low', () => {
        const p = makePlayer({ health: 5 }); // Human max HP 100
        const html = renderPage('Title', p, 'Content');
        expect(html).toContain('Your HP is dangerously low!');
    });

    it('renders ambush-specific low health alert', () => {
        const p = makePlayer({ health: 5, ambushed: true });
        const html = renderPage('Title', p, 'Content');
        expect(html).toContain('Your HP is dangerously low!');
    });

    it('renders XP bar with previous state for animation', () => {
        const p = makePlayer({ experience: 1000, prevExperience: 500 });
        const html = renderPage('Title', p, 'Content');
        expect(html).toBeDefined();
    });

    it('renders different header clickable status', () => {
        const p = makePlayer({ ambushed: true });
        const html = renderPage('Title', p, 'Content');
        expect(html).toBeDefined();
    });

    it('renders simple page correctly', () => {
        const html = renderSimplePage('Simple', 'Content');
        expect(html).toBeDefined();
    });
});

describe('player.view', () => {
    describe('renderDeathView', () => {
        it('assigns heresy message for cheated players', () => {
            const p = makePlayer({ cheated: true });
            renderDeathView(p);
            expect(p.deathReason).toContain('heresy');
        });

        it('assigns specific message for trapped ambushed players', () => {
            const p = makePlayer({ ambushed: true, coward: true });
            renderDeathView(p);
            expect(p.deathReason).toContain('caught trying to flee an ambush');
        });

        it('assigns coward message for non-ambushed cowards', () => {
            const p = makePlayer({ ambushed: false, coward: true });
            renderDeathView(p);
            expect(p.deathReason).toContain('cowardly way out');
        });

        it('assigns random death message for normal deaths', () => {
            const p = makePlayer({ coward: false });
            renderDeathView(p);
            expect(p.deathReason).toBeDefined();
            expect(p.deathReason).not.toContain('cowardly');
        });

        it('preserves existing deathReason if already set', () => {
            const p = makePlayer({ deathReason: 'Custom Death' });
            renderDeathView(p);
            expect(p.deathReason).toBe('Custom Death');
        });
    });

    describe('renderSuicideView', () => {
        it('returns rendered suicide page', () => {
            const p = makePlayer();
            const html = renderSuicideView(p);
            expect(html).toBeDefined();
        });
    });

    describe('renderCharacterView', () => {
        it('returns rendered character page with correct attributes for leveling character', () => {
            const p = makePlayer({
                name: 'Seth',
                raceId: 2, // Elf
                experience: 100,
                totalBattles: 1,
                totalAmbushes: 1,
                totalEnemiesKilled: 1,
            });
            const html = renderCharacterView(p);
            expect(html).toBeDefined();
            expect(html).toContain('Seth');
            expect(html).toContain('a battle');
            expect(html).toContain('a cunning ambush');
            expect(html).toContain('isMaxLevel');
        });

        it('handles plural battles and ambushes', () => {
            const p = makePlayer({
                totalBattles: 5,
                totalAmbushes: 3,
                totalEnemiesKilled: 10,
            });
            const html = renderCharacterView(p);
            expect(html).toContain('5 battles');
            expect(html).toContain('3 cunning ambushes');
        });

        it('handles max level character correctly', () => {
            const p = makePlayer({ experience: 999_999_999 });
            const html = renderCharacterView(p);
            expect(html).toContain('isMaxLevel');
            expect(html).toContain('999,999,999');
        });
    });
});
