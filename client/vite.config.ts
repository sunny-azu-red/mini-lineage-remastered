import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tsconfigPaths from 'vite-tsconfig-paths';

// New Vite-built SPA client. Lives at the repo-root `client/` directory (NOT `src/client/`) so
// the server's CommonJS `tsc` build (tsconfig.build.json, rootDir ".") never has a reason to try
// compiling JSX — see the architectural plan's "Client stack" decision (A2).
export default defineConfig({
    root: __dirname,
    plugins: [react(), tsconfigPaths()],
    build: {
        outDir: '../dist/public',
        emptyOutDir: true,
    },
    server: {
        proxy: {
            '/socket.io': {
                target: 'http://localhost:3000',
                ws: true,
            },
            '/api': {
                target: 'http://localhost:3000',
            },
        },
    },
});
