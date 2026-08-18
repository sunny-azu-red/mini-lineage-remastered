import { describe, it, expect, vi } from 'vitest';
import { renderPage, renderSimplePage } from '@/view/layout.view';
import { PlayerState } from '@/interface';
import { EFFECTS_CONFIG } from '@/constant/game.constant';
import * as versionUtil from '@/util/version.util';
import * as baseView from '@/view/base.view';

vi.mock('@/view/base.view', () => ({
    readTemplate: vi.fn().mockReturnValue({ content: '', filename: 'layout.ejs' }),
    render: vi.fn().mockReturnValue('<html>Layout</html>')
}));

const makePlayer = (overrides: Partial<PlayerState> = {}): PlayerState => ({
    name: 'Test Hero',
    raceId: 0,
    health: 100,
    adena: 0,
    experience: 0,
    weaponId: 0,
    armorId: 0,
    ...overrides,
} as PlayerState);

describe('layout.view', () => {
    describe('renderPage', () => {
        it('renders with release styles when isRelease is true', () => {
            vi.spyOn(versionUtil, 'isRelease').mockReturnValue(true);
            renderPage('Title', makePlayer(), 'Content');
            
            const renderMock = vi.mocked(baseView.render);
            const lastCallArgs = renderMock.mock.calls[renderMock.mock.calls.length - 1][1] as any;
            expect(lastCallArgs.isRelease).toBe(true);
        });

        it('renders with development styles when isRelease is false', () => {
            vi.spyOn(versionUtil, 'isRelease').mockReturnValue(false);
            renderPage('Title', makePlayer(), 'Content');
            
            const renderMock = vi.mocked(baseView.render);
            const lastCallArgs = renderMock.mock.calls[renderMock.mock.calls.length - 1][1] as any;
            expect(lastCallArgs.isRelease).toBe(false);
        });

        it('includes flash message when provided', () => {
            const flash = { text: 'Hello', type: 'info' as const };
            renderPage('Title', makePlayer(), 'Content', flash);
            
            const renderMock = vi.mocked(baseView.render);
            const lastCallArgs = renderMock.mock.calls[renderMock.mock.calls.length - 1][1] as any;
            expect(lastCallArgs.flash).toEqual(flash);
        });

        it('hides low health alert when option is set', () => {
            const p = makePlayer({ health: 5 }); // Low health
            renderPage('Title', p, 'Content', null, { hideLowHealthAlert: true });
            
            const renderMock = vi.mocked(baseView.render);
            const lastCallArgs = renderMock.mock.calls[renderMock.mock.calls.length - 1][1] as any;
            expect(lastCallArgs.lowHealthAlert).toBe('');
        });

        it('shows low health alert when health is low and not hidden', () => {
            const p = makePlayer({ health: 5 }); // Low health
            renderPage('Title', p, 'Content');
            
            const renderMock = vi.mocked(baseView.render);
            const lastCallArgs = renderMock.mock.calls[renderMock.mock.calls.length - 1][1] as any;
            expect(lastCallArgs.lowHealthAlert).not.toBe('');
        });

        it('disables headerClickable when ambushed or dead', () => {
            const p1 = makePlayer({ ambushed: true });
            renderPage('Title', p1, 'Content');
            let renderMock = vi.mocked(baseView.render);
            let lastCallArgs = renderMock.mock.calls[renderMock.mock.calls.length - 1][1] as any;
            expect(lastCallArgs.headerClickable).toBe(false);

            const p2 = makePlayer({ dead: true });
            renderPage('Title', p2, 'Content');
            renderMock = vi.mocked(baseView.render);
            lastCallArgs = renderMock.mock.calls[renderMock.mock.calls.length - 1][1] as any;
            expect(lastCallArgs.headerClickable).toBe(false);
        });
    });

    describe('renderSimplePage', () => {
        it('renders with default headerClickable', () => {
            renderSimplePage('Title', 'Content');
            const renderMock = vi.mocked(baseView.render);
            const lastCallArgs = renderMock.mock.calls[renderMock.mock.calls.length - 1][1] as any;
            expect(lastCallArgs.headerClickable).toBe(true);
        });

        it('handles headerClickable for game started but ambushed', () => {
            const p = makePlayer({ ambushed: true });
            renderSimplePage('Title', 'Content', null, p);
            const renderMock = vi.mocked(baseView.render);
            const lastCallArgs = renderMock.mock.calls[renderMock.mock.calls.length - 1][1] as any;
            expect(lastCallArgs.headerClickable).toBe(false);
        });

        it('handles headerClickable when game is not started', () => {
            renderSimplePage('Title', 'Content', null, { raceId: undefined } as any);
            const renderMock = vi.mocked(baseView.render);
            const lastCallArgs = renderMock.mock.calls[renderMock.mock.calls.length - 1][1] as any;
            expect(lastCallArgs.headerClickable).toBe(true);
        });

        it('handles headerClickable for game started but dead', () => {
            const p = makePlayer({ dead: true });
            renderSimplePage('Title', 'Content', null, p);
            const renderMock = vi.mocked(baseView.render);
            const lastCallArgs = renderMock.mock.calls[renderMock.mock.calls.length - 1][1] as any;
            expect(lastCallArgs.headerClickable).toBe(false);
        });
    });

    describe('renderStatus dead branches', () => {
        it('covers dead status display branch', () => {
            const p = makePlayer({ dead: true });
            renderPage('Title', p, 'Content');
            expect(baseView.render).toHaveBeenCalled();
        });
    });

    describe('renderStatus level up branches', () => {
        it('covers level up animation branches', () => {
            const p = makePlayer({ experience: 1000, prevExperience: 0 });
            renderPage('Title', p, 'Content');
            expect(baseView.render).toHaveBeenCalled();
        });

        it('covers ambushed level display branch', () => {
            const p = makePlayer({ ambushed: true });
            renderPage('Title', p, 'Content');
            expect(baseView.render).toHaveBeenCalled();
        });
    });

    describe('low health ambush branch', () => {
        it('shows ambush specific low health message', () => {
            const p = makePlayer({ health: 5, ambushed: true });
            renderPage('Title', p, 'Content');
            const renderMock = vi.mocked(baseView.render);
            const lastCallArgs = renderMock.mock.calls[renderMock.mock.calls.length - 1][1] as any;
            expect(lastCallArgs.lowHealthAlert).toContain('dangerously low');
        });
    });

    describe('dynamic maxHealth with active effects', () => {
        it('uses getPlayerStats to calculate dynamic maxHp in status panel', () => {
            const renderMock = vi.mocked(baseView.render);
            renderMock.mockClear();

            const p = makePlayer({
                raceId: 2, // Elf base maxHp 75
                health: 225,
                effects: [
                    { ...EFFECTS_CONFIG.konamiCheat }
                ]
            });
            renderPage('Title', p, 'Content');
            // Check status render call
            const statusCall = renderMock.mock.calls.find((c: any) => c[1] && c[1].maxHp !== undefined) as any;
            expect(statusCall).toBeDefined();
            expect(statusCall[1].maxHp).toBe(225);
            expect(statusCall[1].maxHpFormatted).toBe('225');
            expect(statusCall[1].hpPercent).toBe(100);
        });
    });

    describe('renderEffects and effectsHtml in layout', () => {
        it('renders effectsHtml with badge classes in renderPage and renderSimplePage', () => {
            const renderMock = vi.mocked(baseView.render);
            renderMock.mockClear();

            const p = makePlayer({
                raceId: 0,
                effects: [
                    { ...EFFECTS_CONFIG.restingAura },
                    { ...EFFECTS_CONFIG.smokedSausage, expiresAt: Date.now() + 25_000 },
                    { ...EFFECTS_CONFIG.konamiCheat },
                ]
            });
            renderPage('Title', p, 'Content');
            const layoutCall = renderMock.mock.calls.find((c: any) => c[1] && c[1].effectsHtml !== undefined) as any;
            expect(layoutCall).toBeDefined();
            expect(layoutCall[1].effectsHtml).toContain('effect-icon');
            expect(layoutCall[1].effectsHtml).toContain('effect-aura');
            expect(layoutCall[1].effectsHtml).toContain('effect-buff');
            expect(layoutCall[1].effectsHtml).toContain('effect-debuff');
            expect(layoutCall[1].effectsHtml).toContain('data-expires-at');
            expect(layoutCall[1].effectsHtml).toContain('effect-timer');
            expect(layoutCall[1].effectsHtml).toContain('>25<');
            expect(layoutCall[1].effectsHtml).toContain('title="Satisfied (+10 Max HP)"');
            expect(layoutCall[1].effectsHtml).toContain('data-effect-id="resting"');
            expect(layoutCall[1].effectsHtml).toContain(EFFECTS_CONFIG.restingAura.emoji);
            expect(layoutCall[1].effectsHtml).toContain(EFFECTS_CONFIG.smokedSausage.emoji);
            expect(layoutCall[1].effectsHtml).toContain(EFFECTS_CONFIG.konamiCheat.emoji);

            // Also test renderSimplePage
            renderMock.mockClear();
            renderSimplePage('Simple Title', 'Content', null, p);
            const simpleCall = renderMock.mock.calls.find((c: any) => c[1] && c[1].effectsHtml !== undefined) as any;
            expect(simpleCall).toBeDefined();
            expect(simpleCall[1].effectsHtml).toContain('effect-aura');
        });
    });
});
