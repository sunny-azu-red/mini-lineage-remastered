import { useGameStore } from '@/store/gameStore';
import { isReleaseVersion } from '@shared/version';

/**
 * A release build links the version to its tagged commit; a debug build renders it flagged.
 * Both fall back to the client's OWN build when the catalog hasn't arrived yet — `.version-debug`
 * is a claim about the BUILD, not about loading state, so it must never key on the latter.
 */
export default function Footer() {
    const catalog = useGameStore(state => state.catalog);
    const version = catalog?.version ?? __APP_VERSION__;
    const isRelease = catalog?.isRelease ?? isReleaseVersion(version);

    return (
        <div id="copyright">
            {catalog?.commitUrl
                ? <a href={catalog.commitUrl} target="_blank" rel="noopener noreferrer" className="version-link">{version}</a>
                : <span className={isRelease ? undefined : 'version-debug'}>{version}</span>
            } &copy; 2005 &ndash; {catalog?.year ?? new Date().getFullYear()}
        </div>
    );
}
