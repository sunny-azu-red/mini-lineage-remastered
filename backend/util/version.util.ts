import * as fs from 'fs';
import * as path from 'path';
import { env } from '@/config/env.config';
import { isReleaseVersion } from '@shared/version';

export function getVersion(): string {
    try {
        const versionPath = path.join(__dirname, '../../version.txt');
        if (fs.existsSync(versionPath))
            return fs.readFileSync(versionPath, 'utf8').trim();
    } catch {
        // No version file (e.g. a source checkout) — fall through to the dev label.
    }

    return '⚡ development';
}

/** True for a production process or a release-shaped (short git sha) version string. */
export function isRelease(version: string): boolean {
    return env.NODE_ENV === 'production' || isReleaseVersion(version);
}
