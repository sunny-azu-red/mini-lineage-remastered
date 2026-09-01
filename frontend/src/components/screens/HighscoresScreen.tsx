import type { MouseEvent } from 'react';
import type { HighscoreRow } from '@shared/contract';
import { formatAdena, formatNumber, formatShortDate, truncate } from '@shared/format';
import { useGameStore } from '@/store/gameStore';
import { useRequest } from '@/socket/useRequest';
import DataTable, { type Column } from '@/components/common/DataTable';
import BackLink from '@/components/common/BackLink';
import LoadingPanel from '@/components/common/LoadingPanel';

const COLUMNS_MIN_WIDTH = 545;
const NAME_TRUNCATE_LENGTH = 20;

export default function HighscoresScreen() {
    const catalog = useGameStore(state => state.catalog);
    const raceFilter = useGameStore(state => state.highscoreRaceFilter);
    const navigate = useGameStore(state => state.navigate);
    const { data, loading } = useRequest('highscores:list', { raceId: raceFilter });

    // Must stay the FIRST guard: the race-filter row below needs the catalog to render at all.
    if (!catalog)
        return null;

    const rows: HighscoreRow[] = data?.rows ?? [];

    const races = catalog.races;

    function handleFilter(e: MouseEvent<HTMLAnchorElement>, raceId: number | null) {
        e.preventDefault();
        navigate('highscores', { raceFilter: raceId });
    }

    const columns: Column<HighscoreRow>[] = [
        {
            key: 'name',
            header: 'Name',
            render: row => <>{races.find(r => r.id === row.raceId)?.emoji ?? '❓'} {truncate(row.name, NAME_TRUNCATE_LENGTH)}</>,
        },
        { key: 'level', header: 'Level', headerClassName: 'center', className: 'center', render: row => formatNumber(row.level) },
        { key: 'totalXp', header: 'Total XP', className: 'xp', render: row => formatNumber(row.totalXp) },
        { key: 'adena', header: 'Wealth', className: 'gold', render: row => <>🪙 {formatAdena(row.adena)}</> },
        { key: 'created', header: 'Date', className: 'muted', render: row => formatShortDate(row.created) },
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
                {races.map(race => (
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

            {/* `!data`, not `loading` alone: a race-tab re-fetch keeps the previous table on screen. */}
            {loading && !data ? (
                <LoadingPanel label="Consulting the chronicles…" />
            ) : rows.length > 0 ? (
                <DataTable minWidth={COLUMNS_MIN_WIDTH} columns={columns} rows={rows} rowKey={row => `${row.name}-${row.created}`} />
            ) : (
                <p>
                    The halls are silent. No soul has yet earned a place among these hallowed pillars. The
                    chronicle of champions awaits its first entry. Will your name be the first to echo through
                    eternity?
                </p>
            )}

            <BackLink className="last" />
        </>
    );
}
