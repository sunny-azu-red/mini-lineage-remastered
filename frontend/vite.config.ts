import { defineConfig, loadEnv } from 'vite';
import { execSync } from 'child_process';
import path from 'path';
import react from '@vitejs/plugin-react';
import tsconfigPaths from 'vite-tsconfig-paths';

// Computed here (not read from dist/version.txt) because build:frontend runs BEFORE build:backend,
// so that file doesn't exist yet — mirrors what build:backend writes there, from the same APP_VERSION.
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
    // Empty prefix reads every var, not just VITE_-prefixed ones — config-file use only, never
    // exposed to client code. envDir points at the repo root, where .env actually lives.
    const env = loadEnv(mode, rootDir, '');
    // PORT is the backend's own listen port, reused here so the two can never drift out of sync.
    const backendUrl = `${env.DEV_BACKEND_HOST || 'http://localhost'}:${env.PORT || 3000}`;

    return {
        root: __dirname,
        envDir: rootDir,
        plugins: [react(), tsconfigPaths()],
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
