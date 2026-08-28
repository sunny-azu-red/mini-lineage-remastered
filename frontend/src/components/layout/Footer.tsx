import { useGameStore } from '@/store/gameStore';

// Ported from layout.ejs's #copyright block + layout.view.ts's getVersionHtml(): a release build
// links the version to its tagged commit (GameCatalog.commitUrl, non-null exactly when
// catalog.isRelease), a debug build renders it as plain text.
export default function Footer() {
    const catalog = useGameStore(state => state.catalog);
    const year = catalog?.year ?? new Date().getFullYear();

    return (
        <div id="copyright">
            {catalog && (
                catalog.commitUrl ? (
                    <a href={catalog.commitUrl} target="_blank" rel="noopener noreferrer" className="version-link">
                        {catalog.version}
                    </a>
                ) : (
                    <span className="version-debug">{catalog.version}</span>
                )
            )} &copy; 2005 &ndash; {year}
        </div>
    );
}
