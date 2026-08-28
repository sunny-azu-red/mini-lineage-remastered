import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import type { PlayerSnapshot, BattleFightResult } from '@shared/contract';
import { useGameStore } from '@/store/gameStore';

const { requestMock } = vi.hoisted(() => ({ requestMock: vi.fn() }));
vi.mock('@/socket/client', () => ({ request: requestMock }));

const { playSoundMock } = vi.hoisted(() => ({ playSoundMock: vi.fn() }));
vi.mock('@/audio/soundfx', () => ({ playSound: playSoundMock }));

const { default: BattleScreen } = await import('@/components/screens/BattleScreen');

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

function resetStore(overrides: Partial<ReturnType<typeof useGameStore.getState>> = {}) {
    useGameStore.setState(
        {
            status: 'ready',
            player: makePlayer(),
            catalog: null,
            screen: 'battle',
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

describe('BattleScreen', () => {
    beforeEach(() => {
        requestMock.mockReset();
        playSoundMock.mockReset();
        resetStore();
    });

    // THE headline invariant of the entire rewrite (see the plan's "Context" section): an
    // ambush — or any battle at all — can ONLY ever be resolved by an explicit Fight click.
    // Loading, reloading, reconnecting, or simply viewing this screen must never itself call
    // battle:fight. If this test ever fails, the anti-cheat redesign this whole project exists
    // for has regressed back into the exact bug it was built to eliminate.
    it.each([
        ['not ambushed, no prior battle', { ambushed: false }, null],
        ['not ambushed, with a prior battle result', { ambushed: false }, makeBattleResult()],
        ['ambushed', { ambushed: true }, null],
        ['ambushed, with a prior battle result', { ambushed: true }, makeBattleResult({ ambushed: true })],
    ] as const)(
        'never calls battle:fight merely from mounting (%s)',
        (_label, playerOverrides, lastBattle) => {
            resetStore({ player: makePlayer(playerOverrides), lastBattle });
            render(<BattleScreen />);
            expect(requestMock).not.toHaveBeenCalled();
        },
    );

    it('shows a generic, un-narrated Fight prompt when there is no lastBattle yet', () => {
        resetStore({ player: makePlayer({ ambushed: false }), lastBattle: null });
        render(<BattleScreen />);
        expect(screen.getByRole('button', { name: /Fight!/ })).toBeInTheDocument();
        expect(screen.getByRole('link', { name: 'Retreat' })).toBeInTheDocument();
    });

    it('shows the full narrative and "nextMove"/Retreat actions when a lastBattle result exists and the player is not ambushed', () => {
        const lastBattle = makeBattleResult({
            narrative: {
                critLine: 'A CRITICAL strike!',
                killLine: 'You slay a Goblin.',
                deflectionLine: 'Your armor deflects the blow.',
                outcomeLine: 'You gain 10 XP and 3 Adena.',
                ambushLine: null,
                fightPrompt: null,
                nextMove: 'Press onward',
            },
        });
        resetStore({ player: makePlayer({ ambushed: false }), lastBattle });
        render(<BattleScreen />);

        expect(screen.getByText(/A CRITICAL strike!/)).toBeInTheDocument();
        expect(screen.getByText(/You slay a Goblin\./)).toBeInTheDocument();
        expect(screen.getByText(/Your armor deflects the blow\./)).toBeInTheDocument();
        expect(screen.getByText(/You gain 10 XP and 3 Adena\./)).toBeInTheDocument();
        expect(screen.getByRole('button', { name: /Press onward/ })).toBeInTheDocument();
        expect(screen.getByRole('link', { name: 'Retreat' })).toBeInTheDocument();
    });

    it('shows only the ambush narrative and Fight button (no Retreat) while ambushed, regardless of lastBattle', () => {
        resetStore({
            player: makePlayer({ ambushed: true }),
            lastBattle: makeBattleResult({
                ambushed: true,
                narrative: {
                    critLine: null, killLine: 'k', deflectionLine: 'd', outcomeLine: 'o',
                    ambushLine: 'Bandits leap from the treeline!', fightPrompt: 'Fight them!', nextMove: 'Strike',
                },
            }),
        });
        render(<BattleScreen />);

        expect(screen.getByText(/Bandits leap from the treeline!/)).toBeInTheDocument();
        expect(screen.getByRole('button', { name: /Fight them!/ })).toBeInTheDocument();
        expect(screen.queryByRole('link', { name: 'Retreat' })).not.toBeInTheDocument();
    });

    // Direct regression test for the bug shown in the screenshots: the ambushed branch used to be
    // mutually exclusive with the narrative branch, so a real fight's crit/kill/deflection/outcome
    // narrative silently vanished the instant the player got ambushed. battleground.ejs always
    // rendered the narrative unconditionally whenever a result existed, with `ambushed` only ever
    // branching what's rendered BELOW it — this proves BattleScreen now matches that exactly.
    it('shows BOTH the full battle narrative AND the ambush alert/Fight-your-Foe button when ambushed with a real lastBattle result', () => {
        const lastBattle = makeBattleResult({
            ambushed: true,
            narrative: {
                critLine: 'A CRITICAL strike!',
                killLine: 'You slay a Goblin.',
                deflectionLine: 'Your armor deflects the blow.',
                outcomeLine: 'You gain 10 XP and 3 Adena.',
                ambushLine: 'Bandits leap from the treeline!',
                fightPrompt: 'Face your Foe!',
                nextMove: 'Strike',
            },
        });
        resetStore({ player: makePlayer({ ambushed: true }), lastBattle });
        render(<BattleScreen />);

        // The narrative that used to disappear:
        expect(screen.getByText(/A CRITICAL strike!/)).toBeInTheDocument();
        expect(screen.getByText(/You slay a Goblin\./)).toBeInTheDocument();
        expect(screen.getByText(/Your armor deflects the blow\./)).toBeInTheDocument();
        expect(screen.getByText(/You gain 10 XP and 3 Adena\./)).toBeInTheDocument();

        // AND the ambush alert + Face your Foe button, below it:
        expect(screen.getByText(/Bandits leap from the treeline!/)).toBeInTheDocument();
        expect(screen.getByRole('button', { name: /Face your Foe!/ })).toBeInTheDocument();
        expect(screen.queryByRole('link', { name: 'Retreat' })).not.toBeInTheDocument();
    });

    it('falls back to a generic ambush message when ambushed with no narrative available yet', () => {
        resetStore({ player: makePlayer({ ambushed: true }), lastBattle: null });
        render(<BattleScreen />);
        expect(screen.getByText(/You are being ambushed!/)).toBeInTheDocument();
    });

    it('clicking Fight while ambushed follows the identical code path as clicking while not ambushed', async () => {
        resetStore({ player: makePlayer({ ambushed: true }), lastBattle: null });
        requestMock.mockResolvedValue({ ok: true, data: makeBattleResult({ ambushed: false, sound: 'ambush' }) });

        render(<BattleScreen />);
        fireEvent.click(screen.getByRole('button'));

        await waitFor(() => expect(requestMock).toHaveBeenCalledWith('battle:fight', {}));
        await waitFor(() => expect(useGameStore.getState().lastBattle).not.toBeNull());
        expect(playSoundMock).toHaveBeenCalledWith('ambush');
    });

    it('a died:true ack navigates to the death screen', async () => {
        resetStore({ player: makePlayer({ ambushed: false }), lastBattle: null });
        const deadPlayer = makePlayer({ dead: true, deathReason: 'You fought bravely... but not bravely enough.' });
        requestMock.mockResolvedValue({
            ok: true,
            data: makeBattleResult({ player: deadPlayer, died: true, sound: 'death' }),
        });

        render(<BattleScreen />);
        fireEvent.click(screen.getByRole('button', { name: /Fight!/ }));

        await waitFor(() => expect(useGameStore.getState().screen).toBe('death'));
        expect(playSoundMock).toHaveBeenCalledWith('death');
    });

    it('plays the sound from the ack response', async () => {
        resetStore({ player: makePlayer({ ambushed: false }), lastBattle: null });
        requestMock.mockResolvedValue({ ok: true, data: makeBattleResult({ sound: 'crit', outcome: { enemiesKilled: 1, hpLost: 1, damageBlocked: 0, xpGained: 1, adenaGained: 1, isCritical: true, isLevelUp: false } }) });

        render(<BattleScreen />);
        fireEvent.click(screen.getByRole('button', { name: /Fight!/ }));

        await waitFor(() => expect(playSoundMock).toHaveBeenCalledWith('crit'));
    });

    it('renders nothing for an already-dead player (DeathScreen takes over instead)', () => {
        resetStore({ player: makePlayer({ dead: true }) });
        const { container } = render(<BattleScreen />);
        expect(container).toBeEmptyDOMElement();
        expect(requestMock).not.toHaveBeenCalled();
    });
});
