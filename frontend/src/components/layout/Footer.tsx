import { useGameStore } from '@/store/gameStore';

/**
 * A release build links the version to its tagged commit; a debug build renders plain text.
 *
 * The version falls back to the client's OWN build constant when the catalog has not arrived —
 * while connecting, or when the backend is unreachable. That is precisely when knowing which
 * build is loaded matters most, and the server's copy is unavailable by definition.
 */
export default function Footer() {
    const catalog = useGameStore(state => state.catalog);
    const version = catalog?.version ?? __APP_VERSION__;

    return (
        <div id="copyright">
            {catalog?.commitUrl
                ? <a href={catalog.commitUrl} target="_blank" rel="noopener noreferrer" className="version-link">{version}</a>
                : <span className="version-debug">{version}</span>
            } &copy; 2005 &ndash; {catalog?.year ?? new Date().getFullYear()}
        </div>
    );
}
