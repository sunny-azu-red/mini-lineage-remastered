import { describe, it, expect, vi, afterEach } from 'vitest';
import { buildGameCatalog } from '@/socket/serializer/catalog.serializer';
import { RACES, WEAPONS, ARMORS, FOODS, GAME_VERSION, REPO_COMMIT_URL, LOCALE, HP_CONFIG, MAX_LEVEL, CHARACTER_CONFIG } from '@/constant/game.constant';
import { isRelease } from '@/util/version.util';
import { slugify } from '@/util/format.util';

describe('buildGameCatalog', () => {
    it('is memoized: returns the exact same object reference across calls', () => {
        const first = buildGameCatalog();
        const second = buildGameCatalog();
        expect(second).toBe(first);
    });

    it('maps every race to a RaceView with a slugified label and filled traits', () => {
        const catalog = buildGameCatalog();
        expect(catalog.races).toHaveLength(RACES.length);

        for (const race of RACES) {
            const view = catalog.races.find(r => r.id === race.id);
            expect(view).toBeDefined();
            expect(view?.slug).toBe(slugify(race.label));
            expect(view?.label).toBe(race.label);
            expect(view?.enemyRaceId).toBe(race.enemyRaceId);
            expect(view?.traits).toEqual(expect.any(String));
            expect(view?.traits.length).toBeGreaterThan(0);
            expect(view?.traits).not.toMatch(/\{\w+\}/);
        }
    });

    it('maps weapons/armors/foods to ItemView lists of the correct length', () => {
        const catalog = buildGameCatalog();
        expect(catalog.weapons).toHaveLength(WEAPONS.length);
        expect(catalog.armors).toHaveLength(ARMORS.length);
        expect(catalog.foods).toHaveLength(FOODS.length);
    });

    it('flattens item modifiers the same way the player serializer does', () => {
        const catalog = buildGameCatalog();
        const bestWeapon = catalog.weapons.find(w => w.id === 5);
        expect(bestWeapon?.crit).toBe(15);

        const startingWeapon = catalog.weapons.find(w => w.id === 0);
        expect(startingWeapon?.crit).toBeUndefined();
    });

    it('sources static config fields from game constants', () => {
        const catalog = buildGameCatalog();
        expect(catalog.version).toBe(GAME_VERSION);
        expect(catalog.isRelease).toBe(isRelease(GAME_VERSION));
        expect(catalog.year).toBe(new Date().getFullYear());
        expect(catalog.locale).toBe(LOCALE);
        expect(catalog.lowHealthThreshold).toBe(HP_CONFIG.lowHealthThreshold);
        expect(catalog.maxLevel).toBe(MAX_LEVEL);
        expect(catalog.nameMinLength).toBe(CHARACTER_CONFIG.nameMinLength);
        expect(catalog.nameMaxLength).toBe(CHARACTER_CONFIG.nameMaxLength);
    });

    it('reports no commit URL in a development build', () => {
        // No version.txt is ever written into the source tree (only into dist/ at build time),
        // so GAME_VERSION is the '⚡ development' fallback throughout the test run.
        expect(isRelease(GAME_VERSION)).toBe(false);
        expect(buildGameCatalog().commitUrl).toBeNull();
    });
});

describe('buildGameCatalog — release build', () => {
    afterEach(() => {
        vi.doUnmock('@/util/version.util');
        vi.resetModules();
    });

    it('links the version to its commit page (straight concatenation, matching the old layout view)', async () => {
        // buildGameCatalog memoizes into a module-level cache, so the release branch can only be
        // reached through a freshly-instantiated module graph — hence resetModules + doMock +
        // dynamic import rather than the file-level vi.mock used elsewhere (which would also
        // rewrite the dev-build expectations above).
        vi.resetModules();
        vi.doMock('@/util/version.util', async (importOriginal) => {
            const actual = await importOriginal<typeof import('@/util/version.util')>();
            return { ...actual, isRelease: () => true };
        });

        const { buildGameCatalog: buildReleaseCatalog } = await import('@/socket/serializer/catalog.serializer');
        const catalog = buildReleaseCatalog();

        expect(catalog.isRelease).toBe(true);
        // REPO_COMMIT_URL already ends with a trailing slash, so the version is concatenated
        // straight onto it with no separator inserted (matching old layout.view.ts exactly).
        expect(catalog.commitUrl).toBe(`${REPO_COMMIT_URL}${GAME_VERSION}`);
    });
});
