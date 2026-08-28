import { useGameStore } from '@/store/gameStore';

// Ported from layout.ejs's #copyright block. The old EJS distinguished a release build (a link
// to the tagged commit via REPO_COMMIT_URL, a server-only constant not part of the client
// contract) from a debug build (plain text). Until that link target is exposed through
// GameCatalog, both render as plain text — content parity, not full markup parity.
export default function Footer() {
    const catalog = useGameStore(state => state.catalog);
    const year = catalog?.year ?? new Date().getFullYear();

    return (
        <div id="copyright">
            {catalog && <span className="version-debug">{catalog.version}</span>} &copy; 2005 &ndash; {year}
        </div>
    );
}
