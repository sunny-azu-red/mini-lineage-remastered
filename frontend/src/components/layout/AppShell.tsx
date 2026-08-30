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

// An explicit allowlist, not derived from `player` — "does a character exist" and "should this
// screen show a sidebar" are different questions. Game Start, Character, Highscores, Statistics
// and Races all used the sidebar-less layout.
export const SIDEBAR_SCREENS: ReadonlySet<ScreenId> =
    new Set(['home', 'battle', 'weapons', 'armors', 'inn', 'suicide', 'death']);

// The DOM shape is ported from the old layout so the byte-for-byte-ported CSS, which targets
// these exact ids and classes, still applies unmodified.
export default function AppShell({ children, title }: AppShellProps) {
    const player = useGameStore(state => state.player);
    const screen = useGameStore(state => state.screen);
    // Null until the first hydrate lands. Gating here once covers every screen, all of which
    // would otherwise each flash empty.
    const catalog = useGameStore(state => state.catalog);

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
                                {/*
                                 * An ambush needs no global banner: the store pins `screen` to
                                 * 'battle' whenever ambushed, so BattleScreen's own inline
                                 * treatment is always what's on screen.
                                 */}
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
