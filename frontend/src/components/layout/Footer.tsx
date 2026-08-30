import { useGameStore } from '@/store/gameStore';

// A release build links the version to its tagged commit; a debug build renders plain text.
export default function Footer() {
    const catalog = useGameStore(state => state.catalog);

    return (
        <div id="copyright">
            {catalog && (catalog.commitUrl
                ? <a href={catalog.commitUrl} target="_blank" rel="noopener noreferrer" className="version-link">{catalog.version}</a>
                : <span className="version-debug">{catalog.version}</span>
            )} &copy; 2005 &ndash; {catalog?.year ?? new Date().getFullYear()}
        </div>
    );
}
