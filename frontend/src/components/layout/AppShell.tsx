import type { ReactNode } from 'react';
import { useGameStore, type ScreenId } from '@/store/gameStore';
import SiteHeader from './SiteHeader';
import Footer from './Footer';
import Sidebar from '../sidebar/Sidebar';
import EffectsList from '../effects/EffectsList';
import FlashAlert from '../common/FlashAlert';
import NoticeAlert from '../common/NoticeAlert';
import LowHealthAlert from '../common/LowHealthAlert';

interface AppShellProps {
    children: ReactNode;
    /** The current screen's title, rendered as the in-panel heading (see App.tsx's `SCREEN_TITLES`). */
    title: string;
}

// Old app showed the sidebar (layout.ejs, via renderPage) only for these screens — Game Start,
// Character, Highscores, Statistics, and Races all used simple.ejs/renderSimplePage instead (see
// git show 6256e28:src/view/layout.view.ts), even Character despite a character existing. Kept as
// an explicit allowlist rather than derived from `player` state, since "does a character exist"
// and "should this screen show a sidebar" are two different questions.
export const SIDEBAR_SCREENS: ReadonlySet<ScreenId> =
    new Set(['home', 'battle', 'weapons', 'armors', 'inn', 'suicide', 'death']);

// Ported from layout.ejs's DOM shape (#app > #wrapper > #header/#content, #content ->
// #sidebar + #main, #main -> .panel + #copyright) so the byte-for-byte-ported CSS, which
// targets these exact ids/classes, still applies unmodified.
export default function AppShell({ children, title }: AppShellProps) {
    const player = useGameStore(state => state.player);
    const screen = useGameStore(state => state.screen);

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
                                <span className="header-name">{title}</span>
                                <div className="header-effects" id="effects">
                                    <EffectsList effects={player?.effects ?? []} />
                                </div>
                            </div>

                            <div className="panel-body">
                                <NoticeAlert />
                                <FlashAlert />
                                {/*
                                 * Global, self-suppressing alert driven purely by player state.
                                 * An ambush no longer needs a global banner here — the store
                                 * unconditionally pins `screen` to 'battle' whenever
                                 * `player.ambushed`, so BattleScreen's own inline ambush
                                 * treatment is always what's on screen when ambushed; there is
                                 * no other screen this alert could ever be seen from.
                                 */}
                                <LowHealthAlert />
                                {children}
                            </div>
                        </div>

                        <Footer />
                    </div>
                </div>
            </div>
        </div>
    );
}
