import type { ReactNode } from 'react';
import { useGameStore } from '@/store/gameStore';
import SiteHeader from './SiteHeader';
import Footer from './Footer';
import Sidebar from '../sidebar/Sidebar';
import EffectsList from '../effects/EffectsList';
import FlashAlert from '../common/FlashAlert';
import NoticeAlert from '../common/NoticeAlert';
import AmbushBanner from '../common/AmbushBanner';

interface AppShellProps {
    children: ReactNode;
}

// Ported from layout.ejs's DOM shape (#app > #wrapper > #header/#content, #content ->
// #sidebar + #main, #main -> .panel + #copyright) so the byte-for-byte-ported CSS, which
// targets these exact ids/classes, still applies unmodified.
export default function AppShell({ children }: AppShellProps) {
    const player = useGameStore(state => state.player);

    return (
        <div id="app">
            <div id="wrapper">
                <div id="header">
                    <SiteHeader />
                </div>

                <div id="content">
                    {player !== null && <Sidebar />}

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
