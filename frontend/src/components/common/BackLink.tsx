import type { MouseEvent } from 'react';
import { useGameStore } from '@/store/gameStore';

interface BackLinkProps {
    /** Defaults to the started/unstarted wording the old templates used. */
    label?: string;
    className?: string;
}

/** The trailing "go back" link shared by Character, Highscores, Statistics and Races. */
export default function BackLink({ label, className = 'last back' }: BackLinkProps) {
    const player = useGameStore(state => state.player);
    const navigate = useGameStore(state => state.navigate);
    const started = player?.started ?? false;

    function handleClick(e: MouseEvent<HTMLAnchorElement>) {
        e.preventDefault();
        navigate(started ? 'home' : 'start');
    }

    return (
        <p className={className}>
            <a href="#home" onClick={handleClick}>
                {label ?? (started ? 'Continue your journey' : 'Go back to game start')}
            </a>
        </p>
    );
}
