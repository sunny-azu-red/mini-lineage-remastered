import { describe, it, expect, beforeEach } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import type { PlayerSnapshot } from '@shared/contract';
import { useGameStore } from '@/store/gameStore';
import NoticeAlert from '@/components/common/NoticeAlert';

function makePlayer(overrides: Partial<PlayerSnapshot> = {}): PlayerSnapshot {
    return {
        revision: 1, started: true, name: 'Hero', raceId: 1, raceLabel: 'Human', raceEmoji: '🧑',
        health: 80, maxHealth: 100, hpPercent: 80, lowHealth: false,
        experience: 10, level: 2, isMaxLevel: false, xpCurrent: 10, xpRequired: 100, xpPercent: 10, xpNeeded: 90,
        adena: 500, weapon: null, armor: null, stats: null, effects: [],
        dead: false, ambushed: false, coward: false, cheated: false, deathReason: null, highscoreEligible: false,
        counters: { totalBattles: 0, totalAmbushes: 0, consecutiveAmbushes: 0, totalEnemiesKilled: 0 },
        lastBattle: null,
        ...overrides,
    };
}

describe('NoticeAlert', () => {
    beforeEach(() => {
        useGameStore.setState({ player: makePlayer(), notice: null }, false);
    });

    it('renders nothing when there is no notice', () => {
        const { container } = render(<NoticeAlert />);
        expect(container).toBeEmptyDOMElement();
    });

    it('renders the raw server message for a non-rate-limit error', () => {
        useGameStore.setState({ notice: { code: 'INVALID_PAYLOAD', message: 'That is not a valid choice.' } }, false);
        render(<NoticeAlert />);
        expect(screen.getByText(/That is not a valid choice\./)).toBeInTheDocument();
    });

    it('styles a non-rate-limit notice (e.g. a dropped connection) as danger, not warning', () => {
        useGameStore.setState(
            { notice: { code: 'INTERNAL', message: '⭕ You got disconnected from the realm, the backend is offline.' } },
            false,
        );
        const { container } = render(<NoticeAlert />);
        expect(container.querySelector('.alert-danger')).toBeInTheDocument();
        expect(container.querySelector('.alert-warning')).not.toBeInTheDocument();
    });

    it('styles a rate-limit notice as danger, same as any other rejected action', () => {
        useGameStore.setState(
            { notice: { code: 'RATE_LIMITED', message: 'Too many requests. Please slow down.' } },
            false,
        );
        const { container } = render(<NoticeAlert />);
        expect(container.querySelector('.alert-danger')).toBeInTheDocument();
        expect(container.querySelector('.alert-warning')).not.toBeInTheDocument();
    });

    it('shows the generic rate-limit copy, with the retry time folded into the sentence (not the raw server message, and not a redundant second "try again")', () => {
        useGameStore.setState(
            { notice: { code: 'RATE_LIMITED', message: 'Too many requests. Please slow down.', retryAfterMs: 4200 } },
            false,
        );
        render(<NoticeAlert />);

        expect(screen.getByText('You are moving too fast. Please take a breath and try again in 5s.')).toBeInTheDocument(); // ceil(4200/1000)
        expect(screen.queryByText(/Too many requests\. Please slow down\./)).not.toBeInTheDocument();
    });

    it('falls back to "in a moment" when a rate-limit notice carries no retryAfterMs', () => {
        useGameStore.setState(
            { notice: { code: 'RATE_LIMITED', message: 'Too many requests. Please slow down.' } },
            false,
        );
        render(<NoticeAlert />);

        expect(screen.getByText('You are moving too fast. Please take a breath and try again in a moment.')).toBeInTheDocument();
    });

    it('shows the ambush-specific rate-limit copy when the player is currently ambushed', () => {
        useGameStore.setState(
            {
                player: makePlayer({ ambushed: true, dead: false }),
                notice: { code: 'RATE_LIMITED', message: 'Too many requests. Please slow down.' },
            },
            false,
        );
        render(<NoticeAlert />);

        expect(
            screen.getByText(/You are in the middle of an ambush and moving too fast\. Please wait a moment before your next move\./),
        ).toBeInTheDocument();
    });

    it('still appends the "Try again in Ns." sentence to the ambush-specific copy', () => {
        useGameStore.setState(
            {
                player: makePlayer({ ambushed: true, dead: false }),
                notice: { code: 'RATE_LIMITED', message: 'Too many requests. Please slow down.', retryAfterMs: 4200 },
            },
            false,
        );
        render(<NoticeAlert />);

        expect(screen.getByText(/Try again in 5s\./)).toBeInTheDocument();
    });

    it('dismiss button clears the notice', () => {
        useGameStore.setState({ notice: { code: 'INVALID_PAYLOAD', message: 'Nope.' } }, false);
        render(<NoticeAlert />);

        fireEvent.click(screen.getByRole('button', { name: /Dismiss/ }));
        expect(useGameStore.getState().notice).toBeNull();
    });
});
