import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import type { PlayerSnapshot, BattleFightResult } from '@shared/contract';
import { useGameStore } from '@/store/gameStore';

const { requestMock } = vi.hoisted(() => ({ requestMock: vi.fn() }));
vi.mock('@/socket/client', () => ({ request: requestMock }));

const { playSoundMock } = vi.hoisted(() => ({ playSoundMock: vi.fn() }));
vi.mock('@/audio/soundfx', () => ({ playSound: playSoundMock }));

const { default: HomeScreen } = await import('@/components/screens/HomeScreen');

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
        lastBattle: null,
        ...overrides,
    };
}

function makeBattleResult(overrides: Partial<BattleFightResult> = {}): BattleFightResult {
    return {
        player: makePlayer(),
        outcome: { enemiesKilled: 1, hpLost: 5, damageBlocked: 2, xpGained: 10, adenaGained: 3, isCritical: false, isLevelUp: false },
        narrative: {
            critLine: null,
            killLine: 'You slay a Goblin.',
            deflectionLine: 'Your armor deflects the blow.',
            outcomeLine: 'You gain 10 XP and 3 Adena.',
            ambushLine: null,
            fightPrompt: null,
            nextMove: 'Press onward',
        },
        ambushed: false,
        died: false,
        flash: null,
        sound: null,
        ...overrides,
    };
}

function resetStore() {
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
        },
        false,
    );
}

describe('HomeScreen', () => {
    beforeEach(() => {
        requestMock.mockReset();
        // navigate() always calls .then() on this now (to apply the player:screen ack to its
        // own store) — a safe default so tests that don't care about the response don't crash;
        // individual tests below still override it with their own mockResolvedValue.
        requestMock.mockResolvedValue({ ok: false, error: { code: 'INTERNAL', message: 'mock default' } });
        playSoundMock.mockReset();
        resetStore();
    });

    it('selecting Battle navigates to the battle screen AND fires exactly one battle:fight (Home->Battle click fights immediately)', async () => {
        requestMock.mockResolvedValue({ ok: true, data: makeBattleResult() });

        render(<HomeScreen />);

        fireEvent.change(screen.getByRole('combobox'), { target: { value: 'battle' } });
        fireEvent.click(screen.getByRole('button', { name: 'Travel' }));

        expect(useGameStore.getState().screen).toBe('battle');
        await waitFor(() => expect(requestMock).toHaveBeenCalledWith('battle:fight', {}));
        expect(requestMock.mock.calls.filter(call => call[0] === 'battle:fight')).toHaveLength(1);
        await waitFor(() => expect(useGameStore.getState().lastBattle).not.toBeNull());
    });

    it('selecting a non-battle destination just navigates, without calling battle:fight', () => {
        render(<HomeScreen />);

        fireEvent.change(screen.getByRole('combobox'), { target: { value: 'inn' } });
        fireEvent.click(screen.getByRole('button', { name: 'Travel' }));

        expect(useGameStore.getState().screen).toBe('inn');
        expect(requestMock).not.toHaveBeenCalledWith('battle:fight', expect.anything());
    });

    it('defaults the select to the first real destination (Inn), not an empty placeholder', () => {
        render(<HomeScreen />);

        expect(screen.getByRole('combobox')).toHaveValue('inn');
        expect(screen.queryByText('Where to?')).not.toBeInTheDocument();
    });

    it('submitting without changing the selection navigates to Inn (the pre-selected default), not a no-op', () => {
        render(<HomeScreen />);

        fireEvent.click(screen.getByRole('button', { name: 'Travel' }));

        expect(useGameStore.getState().screen).toBe('inn');
        expect(requestMock).not.toHaveBeenCalledWith('battle:fight', expect.anything());
    });
});
