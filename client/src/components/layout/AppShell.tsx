import type { ReactNode } from 'react';
import { useGameStore, type ScreenId } from '@/store/gameStore';
import SiteHeader from './SiteHeader';
import Footer from './Footer';
import Sidebar from '../sidebar/Sidebar';
import EffectsList from '../effects/EffectsList';
import FlashAlert from '../common/FlashAlert';
import NoticeAlert from '../common/NoticeAlert';
import AmbushBanner from '../common/AmbushBanner';
import LowHealthAlert from '../common/LowHealthAlert';

interface AppShellProps {
    children: ReactNode;
}

// Old app showed the sidebar (layout.ejs, via renderPage) only for these screens — Game Start,
// Character, Highscores, Statistics, and Races all used simple.ejs/renderSimplePage instead (see
// git show 6256e28:src/view/layout.view.ts), even Character despite a character existing. Kept as
// an explicit allowlist rather than derived from `player` state, since "does a character exist"
// and "should this screen show a sidebar" are two different questions.
const SIDEBAR_SCREENS: ReadonlySet<ScreenId> =
    new Set(['home', 'battle', 'weapons', 'armors', 'inn', 'suicide', 'death']);

// Ported from layout.ejs's DOM shape (#app > #wrapper > #header/#content, #content ->
// #sidebar + #main, #main -> .panel + #copyright) so the byte-for-byte-ported CSS, which
// targets these exact ids/classes, still applies unmodified.
export default function AppShell({ children }: AppShellProps) {
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
                                <span className="header-name">Mini Lineage</span>
                                <div className="header-effects" id="effects">
                                    <EffectsList effects={player?.effects ?? []} />
                                </div>
                            </div>

                            <div className="panel-body">
                                <NoticeAlert />
                                <FlashAlert />
                                {/*
                                 * Visible on EVERY screen (plan's "Ambush UX" section) — not
                                 * just Battle — so an ambushed player is reminded and offered
                                 * the one-and-only way to resolve it (an explicit Fight click)
                                 * no matter where they've navigated to.
                                 */}
                                <AmbushBanner />
                                {/*
                                 * Same structural slot as AmbushBanner — both are global,
                                 * self-suppressing alerts driven purely by player state. Placed
                                 * after it: an active ambush is the more urgent/actionable
                                 * warning, low health is secondary context.
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
