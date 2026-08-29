import { defineConfig, loadEnv } from 'vite';
import path from 'path';
import react from '@vitejs/plugin-react';
import tsconfigPaths from 'vite-tsconfig-paths';

// Vite-built SPA client. Lives at the repo-root `frontend/` directory (NOT `backend/frontend/`)
// so the server's CommonJS `tsc` build (tsconfig.build.json, rootDir ".") never has a reason to
// try compiling JSX — see the architectural plan's "Client stack" decision (A2).
export default defineConfig(({ mode }) => {
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
