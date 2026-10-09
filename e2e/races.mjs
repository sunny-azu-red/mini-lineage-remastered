/**
 * Every starting set born in a browser, which the walkthrough cannot: it commits to one. Each lands
 * in its own race's village with the numbers docs/rules.md gives it.
 */
import { chromium } from 'playwright';
import { BASE, RACES, reporter, controls, freshStart } from './helpers.mjs';

const { check, failures } = reporter();
const browser = await chromium.launch();
const consoleErrors = [];
const watch = (page) => {
    page.on('console', m => { if (m.type() === 'error') consoleErrors.push(m.text()); });
    page.on('pageerror', e => consoleErrors.push(`pageerror: ${e.message}`));
};

try {
    // ---- every lineage is described before any of them is chosen ------------------------------
    {
        const { context, page } = await freshStart(browser);
        watch(page);
        const { text } = controls(page);
        await page.goto(`${BASE}/races`, { waitUntil: 'domcontentloaded' });
        await page.waitForSelector('.phx-connected', { timeout: 8000 });
        const chronicles = await text('#main');

        for (const race of RACES) {
            check(`Chronicles of Ancestry describes the ${race.label}`,
                chronicles.includes(`${race.emoji} ${race.label}`));
            const slug = race.label.toLowerCase().replace(' ', '-');
            const town = await text(`#town-${slug}`);
            check(`...and names the village they start in`, town.endsWith(`${race.town}.`), town);

            for (const [path, born] of Object.entries(race.classes)) {
                const row = await text(`#class-${slug}-${path}`);
                check(`...and the ${born.name} with the HP and MP it is born with`,
                    row.startsWith(born.name) && row.endsWith(`${born.health} ${born.mp}`), row);
            }
        }
        await context.close();
    }

    // ---- then every set is born, each in a browser of its own ---------------------------------
    for (const race of RACES) {
        for (const [path, born] of Object.entries(race.classes)) {
            console.log(`\n--- ${race.emoji} ${born.name} ---`);
            const { context, page } = await freshStart(browser);
            watch(page);
            const { state, create, text } = controls(page);

            await create(`${born.name.replace(/\s/g, '')}Bot`, race.id, path);
            const now = await state();

            check(`the ${born.name} is welcomed out of ${race.town}`,
                (await text('#main .alert')).includes(`You chose the ${race.emoji} ${born.name}`)
                && (await text('#main .alert')).includes(race.town),
                await text('#main .alert'));
            check(`...and stands in it`, (await text('#main .header-name')) === race.town,
                await text('#main .header-name'));
            check('...at level 1', now.level === 1, String(now.level));
            check(`...with the ${born.name}'s full health`,
                now.health === born.health && now.maxHealth === born.health,
                `${now.health}/${now.maxHealth}, expected ${born.health}`);
            check('...and full mana', now.mp === born.mp && now.maxMp === born.mp,
                `${now.mp}/${now.maxMp}, expected ${born.mp}`);
            check('...and no Adena', now.adena === 0, String(now.adena));
            check('...and the sidebar names the class',
                (await text('#sidebar .stat-row')).includes(`${race.emoji} ${born.name} 1`),
                await text('#sidebar .stat-row'));

            await context.close();
        }
    }

    check('no console errors', consoleErrors.length === 0, consoleErrors.join(' | '));
} catch (err) {
    check(`race walkthrough threw: ${err.message}`, false);
} finally {
    await browser.close();
}

console.log(failures.length === 0 ? '\nAll race checks passed.' : `\n${failures.length} check(s) failed.`);
process.exit(failures.length === 0 ? 0 : 1);
