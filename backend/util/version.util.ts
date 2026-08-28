import * as fs from 'fs';
import * as path from 'path';
import { env } from '@/config/env.config';

export function getVersion(): string {
    try {
        const versionPath = path.join(__dirname, '../../version.txt');
        if (fs.existsSync(versionPath))
            return fs.readFileSync(versionPath, 'utf8').trim();
    } catch (err) {
    }

    return '⚡ development';
}

export function isRelease(version: string): boolean {
    return env.NODE_ENV === 'production' || (version.length === 7 && /^[0-9a-f]+$/i.test(version));
}
