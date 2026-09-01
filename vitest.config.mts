import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';
import tsconfigPaths from 'vite-tsconfig-paths';

// Two projects, split by environment: backend tests (node, root tsconfig's @/* -> backend/*) and
// frontend tests (jsdom, tsconfig.frontend.json's @/* -> frontend/src/*). Tests are NOT colocated
// with source — they live under test/{backend,frontend}/, mirroring the source tree and importing
// via the @/ alias. tsconfig.frontend.json sits at the repo root (an ancestor of both frontend/src/
// and test/frontend/) because vite-tsconfig-paths resolves a config by walking up from the
// importing file, and one living inside frontend/ could never be found from the sibling
// test/frontend/. The frontend project also needs the react() plugin: esbuild's default JSX
// transform picks its settings from the nearest tsconfig.json by the same upward walk, which from
// test/frontend/ would otherwise resolve to the backend's tsconfig.json.
export default defineConfig({
    test: {
        projects: [
            {
                plugins: [tsconfigPaths({ projects: ['./tsconfig.json'] })],
                test: {
                    name: 'backend',
                    globals: true,
                    environment: 'node',
                    include: ['test/backend/**/*.test.ts'],
                },
            },
            {
                plugins: [react(), tsconfigPaths({ projects: ['./tsconfig.frontend.json'] })],
                // frontend/vite.config.ts is not used here, so its build-time constants must be
                // declared again — tests run the equivalent of a dev build.
                define: { __APP_VERSION__: JSON.stringify('⚡ development') },
                test: {
                    name: 'frontend',
                    globals: true,
                    environment: 'jsdom',
                    include: ['test/frontend/**/*.test.{ts,tsx}'],
                    setupFiles: ['./test/frontend/vitest.setup.ts'],
                },
            },
        ],
    },
});
