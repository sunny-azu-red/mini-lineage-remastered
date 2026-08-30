import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';
import tsconfigPaths from 'vite-tsconfig-paths';

// Vitest 4 dropped `environmentMatchGlobs`/root-level `plugins` shared across differently-
// configured suites in favor of `test.projects` — used here for exactly the split this repo
// needs: backend tests (test/backend/**) keep running under the default 'node' environment
// against the root tsconfig's `@/*` (-> backend/*) alias, while ALL frontend tests
// (test/frontend/**/*.test.{ts,tsx}) run under 'jsdom' against `@/*` (-> frontend/src/*). Test
// files are NOT colocated with source — they live under test/frontend/ in a tree mirroring
// frontend/src/, importing their subject-under-test via the `@/` alias rather than a relative
// path. The frontend project points `vite-tsconfig-paths` at the root-level
// tsconfig.frontend.json rather than frontend/tsconfig.json: that plugin associates a tsconfig
// with an importer purely by walking up the importer's own directory tree, so a config living in
// frontend/ can never be discovered by files under the sibling test/frontend/ — tsconfig.frontend.json
// sits at the repo root (an ancestor of both frontend/src/ and test/frontend/) specifically to
// fix that, mirroring how the root tsconfig.json already covers both backend/ and test/backend/.
// Frontend tests get jsdom unconditionally (not just the ones that need it today) because every
// frontend test will eventually need it anyway once component tests land — a single glob per
// project is simpler and less fragile than maintaining a growing exceptions list.
// gameStore.test.ts's pure-logic assertions were verified to still pass fine under jsdom (a
// strict superset of node for non-DOM code). The frontend project also needs the `react()` plugin
// (unlike before the test/frontend split): Vite's default esbuild JSX transform picks its
// jsx/jsxImportSource settings from the nearest tsconfig.json found by walking up from the
// importing file, which — now that tests live under test/frontend/ rather than inside
// frontend/src/ — would resolve to the root (backend) tsconfig.json instead of a
// react-jsx-enabled one. `react()` transforms JSX itself, independent of that lookup.
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
