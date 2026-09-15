/**
 * The Halls of Champions, live — the one thing neither other suite can show.
 *
 * Both of those drive a single browser, so a board that only refreshed for the person who caused
 * the change would pass them both. This opens two contexts, which means two session cookies and
 * two separate players, and watches one player's page change because of what the OTHER one did.
 */
import { chromium } from 'playwright';

const BASE = process.env.E2E_BASE_URL ?? 'http://localhost:4002';
const browser = await chromium.launch();

let failures = 0;
const check = (label, pass, detail = '') => {
    console.log(`${pass ? '✅' : '❌'} ${label}${detail ? ' — ' + detail : ''}`);
    if (!pass) failures++;
};

// Never `networkidle`: the LiveView websocket stays open, so it never settles.
const connected = (page) => page.waitForSelector('.phx-connected', { timeout: 8000 });

try {
    const watcher = await (await browser.newContext()).newPage();
    const player = await (await browser.newContext()).newPage();
    const consoleErrors = [];
    for (const page of [watcher, player])
        page.on('console', (m) => m.type() === 'error' && consoleErrors.push(m.text()));

    await watcher.goto(`${BASE}/highscores`, { waitUntil: 'domcontentloaded' });
    await connected(watcher);
    check('the watcher opens the Halls, with no sign of a player yet to exist',
        !/LiveOne/.test((await watcher.textContent('#main')) ?? ''));

    // Somebody else, in their own session, starts a run. The watcher does nothing at all.
    await player.goto(BASE, { waitUntil: 'domcontentloaded' });
    await connected(player);
    await player.fill('#main input[name="name"]', 'LiveOne');
    await player.selectOption('#main select[name="race_id"]', '2');
    await player.click('#main button[type="submit"]');
    await player.waitForSelector('#screen[data-screen="home"]', { timeout: 8000 });

    check('a run appears on the watcher\'s board the moment it chooses a race',
        await watcher.waitForFunction(
            () => document.querySelector('#main')?.textContent?.includes('LiveOne'),
            null, { timeout: 6000 }).then(() => true).catch(() => false));

    const before = (await watcher.textContent('#main table.data-table .xp'))?.trim();

    await player.goto(`${BASE}/battle`, { waitUntil: 'domcontentloaded' });
    await connected(player);
    await player.click('#main button[phx-click="fight"]');
    await player.waitForFunction(
        () => Number(document.querySelector('#screen')?.dataset.battles ?? 0) > 0,
        null, { timeout: 8000 }).catch(() => {});

    const climbed = await watcher.waitForFunction(
        (prev) => document.querySelector('#main table.data-table .xp')?.textContent?.trim() !== prev,
        before, { timeout: 6000 }).then(() => true).catch(() => false);
    check('...and climbs as they fight, without the watcher reloading anything', climbed,
        `${before} -> ${(await watcher.textContent('#main table.data-table .xp'))?.trim()}`);

    // A stranger's row is a link, and following it must never adopt their character.
    const href = await watcher.getAttribute('#main table.data-table a', 'href');
    check('...at a link to that run\'s own page', /^\/champion\/\S+$/.test(href ?? ''), href ?? '');

    await watcher.goto(`${BASE}${href}`, { waitUntil: 'domcontentloaded' });
    await connected(watcher);
    const record = (await watcher.textContent('#main'))?.replace(/\s+/g, ' ') ?? '';
    check('...showing a stranger\'s stats and their chronicle so far',
        /LiveOne/.test(record) && /was last seen on/.test(record), record.slice(0, 90));
    check('...while the watcher stays a visitor, not that character',
        await watcher.evaluate(() => document.querySelector('#screen')?.dataset.started) === 'false');

    await watcher.goto(`${BASE}/`, { waitUntil: 'domcontentloaded' });
    await connected(watcher);
    check('...and going home offers them a character of their own',
        await watcher.locator('#main input[name="name"]').count() === 1);

    check('no console errors', consoleErrors.length === 0, consoleErrors.join(' | '));
} catch (err) {
    check(`live board threw: ${err.message}`, false);
} finally {
    await browser.close();
}

if (failures > 0) {
    console.log(`\n${failures} check(s) failed.`);
    process.exit(1);
}
console.log('\nAll live-board checks passed.');
