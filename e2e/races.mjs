/**
 * Plays every lineage through a normal game, which the main walkthrough cannot: it commits to one
 * race, so a fault in the other three — a wrong purse, a missing backstory, a race that cannot
 * reach the board — would ship unseen.
 *
 * Asserts identity and arithmetic the screens must show, never how a fight rolls. What each race
 * is worth in combat belongs to balance_golden_test.exs, which can seed the dice; here the dice
 * are real, so nothing is claimed about levels reached or damage dealt.
 *
 * Usage: start the isolated server (`e2e/serve.sh`), then
 *   LD_LIBRARY_PATH=~/.local/lib/playwright-deps node e2e/races.mjs
 */
import { chromium } from 'playwright';
import { BASE, RACES, reporter, controls } from './helpers.mjs';

const a = (label) => `${/^[AEIOU]/i.test(label) ? 'an' : 'a'} ${label}`;

const FIGHT_CAP = 150;

const { check, failures } = reporter();
const browser = await chromium.launch();
const context = await browser.newContext();
const page = await context.newPage();

const consoleErrors = [];
page.on('console', m => { if (m.type() === 'error') consoleErrors.push(m.text()); });
page.on('pageerror', e => consoleErrors.push(`pageerror: ${e.message}`));

const { state, onScreen, goHome, travel, fight, buy, leaveShop, boardRows, activeFilter } = controls(page);
const text = async (sel) => (await page.textContent(sel))?.replace(/\s+/g, ' ').trim() ?? '';
const stat = async (id) => Number((await page.textContent(`#${id}`))?.replace(/,/g, ''));

try {
    await page.goto(BASE, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('.phx-connected', { timeout: 8000 });

    // ---- every lineage is described before any of them is chosen ------------------------------
    await page.goto(`${BASE}/races`, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('.phx-connected', { timeout: 8000 });
    const chronicles = await text('#main');
    for (const race of RACES)
        check(`Chronicles of Ancestry describes the ${race.label}`,
            chronicles.includes(race.label) && chronicles.includes(race.emoji));

    // ---- then each one is actually played -----------------------------------------------------
    for (const race of RACES) {
        console.log(`\n--- ${race.emoji} ${race.label} ---`);
        const name = `${race.label.replace(/\s/g, '')}Bot`;

        await page.goto(BASE, { waitUntil: 'domcontentloaded' });
        await page.waitForSelector('.phx-connected', { timeout: 8000 });
        await onScreen('start');
        await page.fill('#main input[name="name"]', name);
        await page.selectOption('#main select[name="race_id"]', String(race.id));
        await page.click('#main button[type="submit"]');
        await onScreen('home');

        const born = await state();
        check(`the ${race.label} is welcomed by name`,
            new RegExp(`You have chosen the.*${race.label}`).test(await text('#main .alert')),
            await text('#main .alert'));
        check(`...and starts on the ${race.label}'s own purse`, born.adena === race.adena,
            `${born.adena}, expected ${race.adena}`);
        check(`...at the ${race.label}'s full health`,
            born.health === race.health && born.health === born.maxHealth,
            `${born.health}/${born.maxHealth}, expected ${race.health}`);
        check('...at level 1', born.level === 1, String(born.level));
        check('...and the newbie blessing is in hand',
            await page.locator('#effects [data-effect-id="newbie_blessing"]').count() === 1);

        // The Character screen, while the blessing still stands: it lasts five minutes, and these
        // are the numbers it modifies.
        await page.click('#sidebar .stat-row a');
        await onScreen('character');
        check(`the Character screen names the ${race.label}'s ancestry`,
            (await text('#main h2')).includes(`${race.emoji} ${name} of ${race.label} Ancestry`),
            await text('#main h2'));
        check('...and tells the lineage\'s own story',
            (await text('#main p')).length > 80, `${(await text('#main p')).length} chars`);
        check(`...with the ${race.label}'s critical chance`, await stat('char-stat-crit') === race.crit,
            `${await stat('char-stat-crit')}%, expected ${race.crit}%`);
        check('...regeneration', await stat('char-stat-regen') === race.regen,
            `${await stat('char-stat-regen')}, expected ${race.regen}`);
        check('...and ambush risk', await stat('char-stat-ambush') === race.ambush,
            `${await stat('char-stat-ambush')}%, expected ${race.ambush}%`);

        await page.click('#main .back a');
        await onScreen('home');

        // ---- normal play: shops open and price goods, the road runs out at the grave -----------
        for (const [shop, heading] of [['inn', 'Inn'], ['weapons', 'Weapons Shop'], ['armors', 'Armor Shop']]) {
            await travel(shop);
            if ((await state()).screen !== shop)
                break;

            check(`${a(race.label)} can shop at the ${heading}`,
                (await text('#main .header-name')) === heading, await text('#main .header-name'));
            check('...and is offered something to buy',
                await page.locator('#main select[name="item_id"] option').count() > 1);
            await goHome();
        }

        // What a lineage can afford at birth is its purse, not a roll: only the Orc's 250 falls
        // short of an Elven Needle, and it must be told so rather than shown an error page.
        await travel('weapons');
        const NEEDLE = { id: 1, cost: 300 };
        const affordable = race.adena >= NEEDLE.cost;
        const bought = await buy(NEEDLE.id);
        check(`${a(race.label)} ${affordable ? 'can' : 'cannot'} afford an Elven Needle at birth`,
            bought === affordable,
            `purse ${race.adena} against ${NEEDLE.cost}, and it was ${bought ? 'sold' : 'refused'}`);

        if (affordable)
            check('...and carries it out of the shop',
                (await text('#sidebar')).includes('Elven Needle'), await text('#sidebar .panel-body'));
        else
            check('...and is told why, rather than shown an error page',
                /do not have enough Adena/.test(await text('#main .alert-danger')),
                await text('#main .alert-danger'));

        await leaveShop();

        await travel('battle');
        let fights = 0;
        while (fights < FIGHT_CAP && !(await state()).dead) {
            if ((await state()).screen !== 'battle')
                break;

            await fight();
            fights++;
        }

        // Not a claim about the dice: with no healing, health only falls, so the road ends. The
        // cap is a runaway guard, and the count is reported so a change in pace is visible.
        const died = await state();
        check(`${a(race.label)} fights until the road ends`, died.dead === true,
            `dead=${died.dead} after ${fights} fights`);
        check('...and lands on the death screen', died.screen === 'death');

        await page.waitForSelector('.phx-connected', { timeout: 8000 });
        check(`a fallen ${race.label} may write its legacy`,
            await page.locator('#main button:has-text("Write your Legacy")').count() === 1);
        await page.click('#main button:has-text("Write your Legacy")');
        await onScreen('highscores');
        check(`...and the ${race.label} reaches the board`,
            (await text('#main table.data-table')).includes(name));
        check('submitting also clears the character', (await state()).started === false);
    }

    // ---- the board can be read one lineage at a time -------------------------------------------
    // Only reachable here: with four races on the board, every filter has something to narrow to.
    console.log('\n--- the board, by lineage ---');
    await page.goto(`${BASE}/highscores`, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('.phx-connected', { timeout: 8000 });
    const allRows = await boardRows();
    check('the board opens on All', (await activeFilter()) === 'All', await activeFilter());
    check('...showing the fallen', allRows > 0, `${allRows} rows`);

    for (const race of RACES) {
        await page.click(`#main .action-links a:has-text("${race.label}") >> nth=0`);
        await page.waitForFunction(
            expected => document.querySelector('#main .action-links a.active')?.textContent.includes(expected),
            race.label, { timeout: 5000 }).catch(() => {});

        const rows = await boardRows();
        check(`filtering to ${race.plural} shows only ${race.plural}`,
            rows > 0 && rows <= allRows && (await activeFilter())?.includes(race.label),
            `${rows} of ${allRows} rows, active "${await activeFilter()}"`);
        check(`...every row on it is ${a(race.label)}`,
            (await page.locator('#main table.data-table tbody tr').allTextContents())
                .every(row => row.includes(race.emoji)),
            (await page.locator('#main table.data-table tbody tr').allTextContents())[0]?.trim());

        await page.click('#main .action-links a:has-text("All")');
        await page.waitForFunction(() => location.pathname === '/highscores', null, { timeout: 5000 });
    }

    check('no console errors', consoleErrors.length === 0, consoleErrors.join(' | '));
} catch (err) {
    check(`race walkthrough threw: ${err.message}`, false);
} finally {
    await browser.close();
}

console.log(failures.length === 0 ? '\nAll race checks passed.' : `\n${failures.length} check(s) failed.`);
process.exit(failures.length === 0 ? 0 : 1);
