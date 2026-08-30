import { useGameStore } from '@/store/gameStore';
import { isReleaseVersion } from '@shared/version';

/**
 * A release build links the version to its tagged commit; a debug build renders it in the warning
 * colour. Both the version and that release/debug judgement fall back to the client's OWN build
 * when the catalog has not arrived — while connecting, or when the backend is unreachable.
 *
 * The `.version-debug` class is a claim about the BUILD, not about whether the catalog has loaded
 * yet: keying it on the latter made a production bundle flag itself red for the whole loading
 * window, then quietly correct itself once the server answered.
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
