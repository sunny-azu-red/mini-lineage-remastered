import type { ReactNode } from 'react';
import { useGameStore, type ScreenId } from '@/store/gameStore';
import SiteHeader from './SiteHeader';
import Footer from './Footer';
import Sidebar from '../sidebar/Sidebar';
import EffectsList from '../effects/EffectsList';
import FlashAlert from '../common/FlashAlert';
import NoticeAlert from '../common/NoticeAlert';
import LowHealthAlert from '../common/LowHealthAlert';
import LoadingPanel from '../common/LoadingPanel';

interface AppShellProps {
    children: ReactNode;
    /** The current screen's title, rendered as the in-panel heading. */
    title: string;
}

// An explicit allowlist, not derived from `player` — "has a character" and "shows a sidebar" are
// different questions (Character, Highscores, Statistics, Races and Game Start never show one).
export const SIDEBAR_SCREENS: ReadonlySet<ScreenId> =
    new Set(['home', 'battle', 'weapons', 'armors', 'inn', 'suicide', 'death']);

export default function AppShell({ children, title }: AppShellProps) {
    const player = useGameStore(state => state.player);
    const screen = useGameStore(state => state.screen);
    const catalog = useGameStore(state => state.catalog); // null until the first hydrate lands

    return (
        <div id="app">
            <div id="wrapper">
                <div id="header">
                    <SiteHeader />
                </div>

                <div id="content">
                    {player?.started && SIDEBAR_SCREENS.has(screen) && <Sidebar />}

                    <div id="main">
                        <div className="panel">
                            <div className="panel-header flex">
                                <span className="header-name">{catalog ? title : 'Loading'}</span>
                                <div className="header-effects" id="effects">
                                    <EffectsList effects={player?.effects ?? []} />
                                </div>
                            </div>

                            <div className="panel-body">
                                <NoticeAlert />
                                <FlashAlert />
                                {/* An ambush needs no global banner: the store pins `screen` to 'battle'. */}
                                <LowHealthAlert />
                                {catalog ? children : <LoadingPanel />}
                            </div>
                        </div>

                        <Footer />
                    </div>
                </div>
            </div>
        </div>
    );
}
