import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import type { PlayerSnapshot } from '@shared/contract';
import { useGameStore } from '@/store/gameStore';

const { requestMock } = vi.hoisted(() => ({ requestMock: vi.fn() }));
vi.mock('@/socket/client', () => ({ request: requestMock }));

const { playSoundMock } = vi.hoisted(() => ({ playSoundMock: vi.fn() }));
vi.mock('@/audio/soundfx', () => ({ playSound: playSoundMock }));

const { default: AmbushBanner } = await import('./AmbushBanner');

function makePlayer(overrides: Partial<PlayerSnapshot> = {}): PlayerSnapshot {
    return {
        revision: 1,
        started: true,
        name: 'Hero',
        raceId: 1,
        raceLabel: 'Human',
        raceEmoji: '🧑',
        health: 80,
        maxHealth: 100,
        hpPercent: 80,
        lowHealth: false,
        experience: 10,
        level: 2,
        isMaxLevel: false,
        xpCurrent: 10,
        xpRequired: 100,
        xpPercent: 10,
        xpNeeded: 90,
        adena: 500,
        weapon: null,
        armor: null,
        stats: null,
        effects: [],
        dead: false,
        ambushed: false,
        coward: false,
        cheated: false,
        deathReason: null,
        highscoreEligible: false,
        counters: { totalBattles: 0, totalAmbushes: 0, consecutiveAmbushes: 0, totalEnemiesKilled: 0 },
        ...overrides,
    };
}

function resetStore(overrides: Partial<ReturnType<typeof useGameStore.getState>> = {}) {
    useGameStore.setState(
        {
            status: 'ready',
            player: makePlayer(),
            catalog: null,
            screen: 'home',
            highscoreRaceFilter: null,
            flash: null,
            lastBattle: null,
            notice: null,
            soundEnabled: false,
            ...overrides,
        },
        false,
    );
}

describe('AmbushBanner', () => {
    beforeEach(() => {
        requestMock.mockReset();
        playSoundMock.mockReset();
        resetStore();
    });

    it('renders nothing when the player is not ambushed', () => {
        resetStore({ player: makePlayer({ ambushed: false }) });
        const { container } = render(<AmbushBanner />);
        expect(container).toBeEmptyDOMElement();
    });

    it('renders nothing on the Battle screen itself (BattleScreen shows the same treatment inline)', () => {
        resetStore({ player: makePlayer({ ambushed: true }), screen: 'battle' });
        const { container } = render(<AmbushBanner />);
        expect(container).toBeEmptyDOMElement();
    });

    it('falls back to a generic message when no battle narrative is available yet', () => {
        // This is the fresh-page-load/reconnect case: hydrate reported ambushed:true but no
        // battle:fight ack (and therefore no narrative) has ever landed in this session.
        resetStore({ player: makePlayer({ ambushed: true }), lastBattle: null });
        render(<AmbushBanner />);
        expect(screen.getByText(/You are being ambushed!/)).toBeInTheDocument();
    });

    it('shows the real ambush narrative line when a battle result is available', () => {
        resetStore({
            player: makePlayer({ ambushed: true }),
            lastBattle: {
                player: makePlayer({ ambushed: true }),
                outcome: { enemiesKilled: 1, hpLost: 1, damageBlocked: 0, xpGained: 1, adenaGained: 1, isCritical: false, isLevelUp: false },
                narrative: {
                    critLine: null, killLine: 'k', deflectionLine: 'd', outcomeLine: 'o',
                    ambushLine: 'Goblins spring from the shadows!', fightPrompt: 'Face your Foe!', nextMove: 'Strike',
                },
                ambushed: true,
                died: false,
                flash: null,
                sound: 'ambush',
            },
        });
        render(<AmbushBanner />);
        expect(screen.getByText(/Goblins spring from the shadows!/)).toBeInTheDocument();
        expect(screen.getByRole('button', { name: /Face your Foe!/ })).toBeInTheDocument();
    });

    it('clicking Fight calls the same battle:fight action used by BattleScreen and navigates to battle', async () => {
        resetStore({ player: makePlayer({ ambushed: true }), screen: 'character' });
        requestMock.mockResolvedValue({
            ok: true,
            data: {
                player: makePlayer({ ambushed: false }),
                outcome: { enemiesKilled: 1, hpLost: 1, damageBlocked: 0, xpGained: 1, adenaGained: 1, isCritical: false, isLevelUp: false },
                narrative: { critLine: null, killLine: 'k', deflectionLine: 'd', outcomeLine: 'o', ambushLine: null, fightPrompt: null, nextMove: 'Strike' },
                ambushed: false,
                died: false,
                flash: null,
                sound: null,
            },
        });

        render(<AmbushBanner />);
        fireEvent.click(screen.getByRole('button'));

        expect(useGameStore.getState().screen).toBe('battle');
        await waitFor(() => expect(requestMock).toHaveBeenCalledWith('battle:fight', {}));
    });
});
