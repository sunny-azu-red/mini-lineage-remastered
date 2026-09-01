import type { MouseEvent } from 'react';
import { useGameStore } from '@/store/gameStore';
import SoundToggle from './SoundToggle';

// Always clickable: navigate() pins to 'battle'/'death' anyway, so it just redirects when blocked.
// SoundToggle sits OUTSIDE the anchor so clicking it never also navigates.
export default function SiteHeader() {
    const player = useGameStore(state => state.player);
    const navigate = useGameStore(state => state.navigate);

    function handleClick(e: MouseEvent<HTMLAnchorElement>) {
        e.preventDefault();
        navigate(player?.started ? 'home' : 'start');
    }

    return (
        <div id="site-header">
            <a href="#home" id="header-link" className="header-clickable-area" onClick={handleClick}>
                <svg className="header-emblem" xmlns="http://www.w3.org/2000/svg" viewBox="58 0 50 157">
                    <g>
                        <path
                            fill="#c9a84c"
                            d="M88.696 135.174c0 14.37 8.958 19.79 8.958 19.79-5.312-8.229-4.688-19.9-4.688-19.9l-.105-111.5c-.103-13.23 5-21.04 5-21.04-9.584 8.645-9.166 21.04-9.166 21.04v111.6m-18.999-.09c0 14.38-8.96 19.79-8.96 19.79 5.313-8.23 4.689-19.9 4.689-19.9l.104-111.5c.104-13.23-5-21.04-5-21.04 9.584 8.646 9.167 21.04 9.167 21.04v111.6"
                        />
                    </g>
                </svg>
                <span className="header-title">Mini Lineage</span>
                <span className="header-subtitle">Remastered</span>
            </a>
            <SoundToggle />
        </div>
    );
}
