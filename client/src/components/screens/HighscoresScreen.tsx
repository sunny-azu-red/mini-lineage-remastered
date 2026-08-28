import { useEffect, useState, type MouseEvent } from 'react';
import type { HighscoreRow } from '@shared/contract';
import { formatAdena, formatNumber, formatShortDate, truncate } from '@shared/format';
import { useGameStore } from '@/store/gameStore';
import { request } from '@/socket/client';
import DataTable, { type Column } from '@/components/common/DataTable';

// `highscores:list` is a read-only event — it never fails with a rejectable game-state error
// (no AMBUSHED routing applies to it), so it's fetched directly via `request()` in an effect
// rather than through `useAction` (which exists specifically to handle mutating actions' pending
// state + AMBUSHED self-heal). StatisticsScreen follows the identical pattern for consistency.
const COLUMNS_MIN_WIDTH = 545;

// Matches today's highscores.view.ts's `truncate(score.name, 20)` call exactly.
const NAME_TRUNCATE_LENGTH = 20;

export default function HighscoresScreen() {
    const catalog = useGameStore(state => state.catalog);
    const player = useGameStore(state => state.player);
    const raceFilter = useGameStore(state => state.highscoreRaceFilter);
    const navigate = useGameStore(state => state.navigate);
    const [rows, setRows] = useState<HighscoreRow[]>([]);

    useEffect(() => {
        let cancelled = false;

        void request('highscores:list', { raceId: raceFilter }).then(res => {
            if (!cancelled && res.ok)
                setRows(res.data.rows);
        });

        return () => {
            cancelled = true;
        };
    }, [raceFilter]);

    if (!catalog)
        return null;

    function raceEmoji(raceId: number): string {
        return catalog!.races.find(r => r.id === raceId)?.emoji ?? '❓';
    }

    function handleFilter(e: MouseEvent<HTMLAnchorElement>, raceId: number | null) {
        e.preventDefault();
        navigate('highscores', { raceFilter: raceId });
    }

    function handleBack(e: MouseEvent<HTMLAnchorElement>) {
        e.preventDefault();
        navigate(player?.started ? 'home' : 'start');
    }

    const columns: Column<HighscoreRow>[] = [
        { key: 'rank', header: 'Rank', render: row => formatNumber(row.rank) },
        {
            key: 'name',
            header: 'Name',
            render: row => (
                <>
                    {raceEmoji(row.raceId)} {truncate(row.name, NAME_TRUNCATE_LENGTH)}
                </>
            ),
        },
        { key: 'level', header: 'Level', render: row => formatNumber(row.level) },
        { key: 'totalXp', header: 'Total XP', render: row => <span className="xp">{formatNumber(row.totalXp)}</span> },
        {
            key: 'adena',
            header: 'Wealth',
            render: row => (
                <span className="gold">
                    🪙 {formatAdena(row.adena)}
                </span>
            ),
        },
        {
            key: 'created',
            header: 'Date',
            render: row => <span className="muted">{formatShortDate(row.created)}</span>,
        },
    ];

    return (
        <>
            <div className="action-links top">
                <a
                    href="#highscores"
                    className={`btn btn-secondary btn-sm${raceFilter === null ? ' active' : ''}`}
                    onClick={e => handleFilter(e, null)}
                >
                    All
                </a>
                {catalog.races.map(race => (
                    <a
                        key={race.id}
                        href={`#highscores/${race.slug}`}
                        className={`btn btn-secondary btn-sm${raceFilter === race.id ? ' active' : ''}`}
                        onClick={e => handleFilter(e, race.id)}
                    >
                        {race.emoji} {race.label}
                    </a>
                ))}
            </div>

            {rows.length > 0 ? (
                <DataTable minWidth={COLUMNS_MIN_WIDTH} columns={columns} rows={rows} rowKey={row => row.rank} />
            ) : (
                <p>
                    The halls are silent. No soul has yet earned a place among these hallowed pillars. The
                    chronicle of champions awaits its first entry. Will your name be the first to echo through
                    eternity?
                </p>
            )}

            <p className="last">
                <a href="#home" onClick={handleBack}>
                    {player?.started ? 'Continue your journey' : 'Go back to game start'}
                </a>
            </p>
        </>
    );
}
