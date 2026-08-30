import { defineConfig, loadEnv } from 'vite';
import { execSync } from 'child_process';
import path from 'path';
import react from '@vitejs/plugin-react';
import tsconfigPaths from 'vite-tsconfig-paths';

// Vite-built SPA client. Lives at the repo-root `frontend/` directory (NOT `backend/frontend/`)
// so the server's CommonJS `tsc` build (tsconfig.build.json, rootDir ".") never has a reason to
// try compiling JSX — see the architectural plan's "Client stack" decision (A2).
/**
 * The client's own build version, baked in at compile time.
 *
 * Mirrors what `build:backend` writes into `dist/version.txt` — `${APP_VERSION:-$(git rev-parse
 * --short HEAD || echo 'unknown')}` — and what `getVersion()` falls back to in a source checkout.
 * Both halves are built from one `npm run build` with the same APP_VERSION exported, so they
 * agree by construction.
 *
 * It is computed here rather than read from version.txt because `build:frontend` runs BEFORE
 * `build:backend`, so that file does not exist yet.
 */
function buildVersion(command: string, env: Record<string, string>): string {
    if (command !== 'build')
        return '⚡ development';
    if (env.APP_VERSION)
        return env.APP_VERSION;

    try {
        return execSync('git rev-parse --short HEAD', { encoding: 'utf8' }).trim();
    } catch {
        return 'unknown';
    }
}

export default defineConfig(({ command, mode }) => {
    const rootDir = path.resolve(__dirname, '..');
    // Empty prefix reads every var (not just VITE_-prefixed ones) for use here in the config
    // file only — never exposed to client code. envDir points at the repo root, where `.env`
    // actually lives (root: __dirname above would otherwise make Vite look inside frontend/).
    const env = loadEnv(mode, rootDir, '');
    // Port comes from PORT (the backend's own listen port) rather than a second var, so the
    // two can never drift out of sync — only the host/protocol is separately configurable.
    const backendUrl = `${env.DEV_BACKEND_HOST || 'http://localhost'}:${env.PORT || 3000}`;

    return {
        root: __dirname,
        envDir: rootDir,
        plugins: [react(), tsconfigPaths()],
        // Lets the footer name the running build even before (or without) a server connection.
        define: { __APP_VERSION__: JSON.stringify(buildVersion(command, env)) },
        build: {
            outDir: '../dist/public',
            emptyOutDir: true,
        },
        server: {
            port: Number(env.DEV_FRONTEND_PORT) || 5173,
            proxy: {
                '/socket.io': { target: backendUrl, ws: true },
                '/api': { target: backendUrl },
            },
        },
    };
});
