import { describe, it, expect, vi } from 'vitest';
import { renderBattlegroundView } from '@/view/battle.view';
import { PlayerState, BattleResult } from '@/interface';
import { RACES } from '@/constant/game.constant';
import * as baseView from '@/view/base.view';

vi.mock('@/view/base.view', () => ({
    readTemplate: vi.fn().mockReturnValue({ content: '', filename: 'battleground.ejs' }),
    render: vi.fn().mockReturnValue('<html>Battleground Content</html>')
}));

vi.mock('@/view/layout.view', () => ({
    renderPage: vi.fn().mockImplementation((title, player, content) => content),
}));

const makeResults = (overrides: Partial<BattleResult> = {}): BattleResult => ({
    enemiesKilled: 1,
    hpLost: 10,
    damageBlocked: 5,
    xpGained: 100,
    adenaGained: 50,
    isCritical: false,
    isLevelUp: false,
    ...overrides,
});

const makePlayer = (overrides: Partial<PlayerState> = {}): PlayerState => ({
    raceId: 0,
    health: 100,
    adena: 0,
    experience: 0,
    weaponId: 0,
    armorId: 0,
    ...overrides,
} as PlayerState);

describe('battle.view', () => {
    describe('renderBattlegroundView scenarios', () => {
        it('assigns Orcs as opponents for Humans', () => {
            const human = makePlayer({ raceId: 0 }); // Human
            renderBattlegroundView(human, makeResults());
            
            const renderMock = vi.mocked(baseView.render);
            const lastCallArgs = renderMock.mock.calls[renderMock.mock.calls.length - 1][1] as any;
            expect(lastCallArgs?.killLine).toContain('Orc');
        });

        it('includes critical hit line when isCritical is true', () => {
            const p = makePlayer();
            renderBattlegroundView(p, makeResults({ isCritical: true }));
            
            const renderMock = vi.mocked(baseView.render);
            const lastCallArgs = renderMock.mock.calls[renderMock.mock.calls.length - 1][1] as any;
            expect(lastCallArgs?.critLine).toBeDefined();
            expect(lastCallArgs?.critLine).not.toBe('');
        });

        it('shows ambush line when player is ambushed', () => {
            const p = makePlayer({ ambushed: true });
            renderBattlegroundView(p, makeResults());
            
            const renderMock = vi.mocked(baseView.render);
            const lastCallArgs = renderMock.mock.calls[renderMock.mock.calls.length - 1][1] as any;
            expect(lastCallArgs?.ambushed).toBe(true);
            expect(lastCallArgs?.ambushedLine).toBeDefined();
        });

        it('uses level up templates when isLevelUp is true', () => {
            const p = makePlayer();
            renderBattlegroundView(p, makeResults({ isLevelUp: true }));
            
            const renderMock = vi.mocked(baseView.render);
            const lastCallArgs = renderMock.mock.calls[renderMock.mock.calls.length - 1][1] as any;
            expect(lastCallArgs?.outcomeLine).toBeDefined();
        });

        it('uses "Face your Foe!" text for single ambush enemy', () => {
            const p = makePlayer({ ambushed: true });
            renderBattlegroundView(p, makeResults({ enemiesKilled: 1 }));
            const renderMock = vi.mocked(baseView.render);
            const lastCallArgs = renderMock.mock.calls[renderMock.mock.calls.length - 1][1] as any;
            expect(lastCallArgs?.fightText).toBe('Face your Foe!');
        });

        it('uses "Fight them!" text for multiple ambush enemies', () => {
            const p = makePlayer({ ambushed: true });
            renderBattlegroundView(p, makeResults({ enemiesKilled: 10 }));
            const renderMock = vi.mocked(baseView.render);
            const lastCallArgs = renderMock.mock.calls[renderMock.mock.calls.length - 1][1] as any;
            expect(lastCallArgs?.fightText).toBe('Fight them!');
        });

        it('assigns "crit" sound when critical hit lands without ambush or flash sound', () => {
            const p = makePlayer();
            renderBattlegroundView(p, makeResults({ isCritical: true }));
            const renderMock = vi.mocked(baseView.render);
            const lastCallArgs = renderMock.mock.calls[renderMock.mock.calls.length - 1][1] as any;
            expect(lastCallArgs?.sound).toBe('crit');
        });

        it('assigns "ambush" sound when player is ambushed without flash sound', () => {
            const p = makePlayer({ ambushed: true });
            renderBattlegroundView(p, makeResults());
            const renderMock = vi.mocked(baseView.render);
            const lastCallArgs = renderMock.mock.calls[renderMock.mock.calls.length - 1][1] as any;
            expect(lastCallArgs?.sound).toBe('ambush');
        });

        it('omits sound when flash already provides a sound', () => {
            const p = makePlayer({ ambushed: true });
            renderBattlegroundView(p, makeResults({ isCritical: true }), { text: 'Level Up', type: 'warning', sound: 'level' });
            const renderMock = vi.mocked(baseView.render);
            const lastCallArgs = renderMock.mock.calls[renderMock.mock.calls.length - 1][1] as any;
            expect(lastCallArgs?.sound).toBeUndefined();
        });

        it('omits sound during regular combat', () => {
            const p = makePlayer();
            renderBattlegroundView(p, makeResults());
            const renderMock = vi.mocked(baseView.render);
            const lastCallArgs = renderMock.mock.calls[renderMock.mock.calls.length - 1][1] as any;
            expect(lastCallArgs?.sound).toBeUndefined();
        });
    });
});
