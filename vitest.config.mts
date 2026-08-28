import { defineConfig } from 'vitest/config';
import tsconfigPaths from 'vite-tsconfig-paths';

// Vitest 4 dropped `environmentMatchGlobs`/root-level `plugins` shared across differently-
// configured suites in favor of `test.projects` — used here for exactly the split this repo
// needs: server tests (test/**) keep running under the default 'node' environment against the
// root tsconfig's `@/*` (-> src/*) alias, while ALL client tests (client/src/**/*.test.{ts,tsx})
// run under 'jsdom' against the client tsconfig's own `@/*` (-> client/src/*) alias. Client tests
// get jsdom unconditionally (not just the ones that need it today) because every client test will
// eventually need it anyway once component tests land — a single glob per project is simpler and
// less fragile than maintaining a growing exceptions list. gameStore.test.ts's pure-logic
// assertions were verified to still pass fine under jsdom (a strict superset of node for
// non-DOM code).
export default defineConfig({
    test: {
        projects: [
            {
                plugins: [tsconfigPaths({ projects: ['./tsconfig.json'] })],
                test: {
                    name: 'server',
                    globals: true,
                    environment: 'node',
                    include: ['test/**/*.test.ts'],
                },
            },
            {
                plugins: [tsconfigPaths({ projects: ['./client/tsconfig.json'] })],
                test: {
                    name: 'client',
                    globals: true,
                    environment: 'jsdom',
                    include: ['client/src/**/*.test.{ts,tsx}'],
                    setupFiles: ['./client/src/vitest.setup.ts'],
                },
            },
        ],
    },
});
