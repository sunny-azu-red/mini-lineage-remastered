/**
 * The Halls, live. The other two drive a single browser, so a board that refreshed only for
 * whoever caused the change would pass them both. Two contexts here means two session cookies and
 * two players, and it watches one player's page move because of what the OTHER one did.
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

// `data-value`, never the text: every figure on the board counts up to its new value, so what is
// rendered mid-tween is a frame and not a number anybody wrote. Read the text and a wait for the
// figure to move returns on the first frame of the animation, hundreds short of the real one.
const XP_CELL = '#main table.data-table [data-key^="xp-"]';
const boardXp = (page) =>
    page.evaluate((cell) => Number(document.querySelector(cell)?.dataset.value ?? -1), XP_CELL);

const xpClimbedPast = (page, was) => page.waitForFunction(
    ([cell, had]) => {
        const xp = document.querySelector(cell);
        return !!xp && Number(xp.dataset.value) > had;
    },
    [XP_CELL, was], { timeout: 8000 });

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

    check('...marked as somebody online right now, not merely alive',
        await watcher.locator('#main table.data-table tbody tr.alive .online').count() === 1,
        await watcher.locator('#main table.data-table tbody tr').first().textContent());

    const before = await boardXp(watcher);

    await player.goto(`${BASE}/battle`, { waitUntil: 'domcontentloaded' });
    await connected(player);
    await player.click('#main button[phx-click="fight"]');
    await player.waitForFunction(
        () => Number(document.querySelector('#screen')?.dataset.battles ?? 0) > 0,
        null, { timeout: 8000 }).catch(() => {});

    const climbed = await xpClimbedPast(watcher, before).then(() => true).catch(() => false);
    check('...and climbs as they fight, without the watcher reloading anything', climbed,
        `${before} -> ${await boardXp(watcher)} XP`);

    // One more before the record is opened. Two entries only just outgrow the Chronicle's box, and
    // whether they do at all turns on a crit line landing — which is the dice deciding whether the
    // check below can see anything. Three clear it however they read.
    await player.click('#main button[phx-click="fight"]');
    await player.waitForFunction(
        () => Number(document.querySelector('#screen')?.dataset.battles ?? 0) > 1,
        null, { timeout: 8000 }).catch(() => {});

    const fought = await boardXp(watcher);

    // A stranger's row is a link, and following it must never adopt their character.
    const href = await watcher.getAttribute('#main table.data-table a', 'href');
    check('...at a link to that run\'s own record', /^\/character\/\S+$/.test(href ?? ''), href ?? '');

    // Read at phone width from here on: two fights wrap to more lines than the Chronicle's box can
    // show, which is what makes following it down observable at all — and what a reader on a phone
    // gets anyway.
    await watcher.setViewportSize({ width: 320, height: 800 });
    await watcher.goto(`${BASE}${href}`, { waitUntil: 'domcontentloaded' });
    await connected(watcher);
    const record = (await watcher.textContent('#main'))?.replace(/\s+/g, ' ') ?? '';
    check('...showing a stranger\'s stats and their chronicle so far',
        /LiveOne/.test(record) && /last carrying/.test(record), record.slice(0, 90));
    check('...while the watcher stays a visitor, not that character',
        await watcher.evaluate(() => document.querySelector('#screen')?.dataset.started) === 'false');

    // The Chronicle opens shut, so a reader watching one has to ask for it first.
    await watcher.click('#chronicle .panel-toggle');

    // The chronicle is APPENDED to while it is being read, never re-read: the reader keeps the
    // fights it already has. Dice-proof — the line is added whether that blow lands or kills.
    const lines = () => watcher.locator('#main ol.chronicle li').count();
    const told = await lines();
    await player.click('#main button[phx-click="fight"]');
    const gained = await watcher.waitForFunction(
        (had) => document.querySelectorAll('#main ol.chronicle li').length > had,
        told, { timeout: 8000 }).then(() => true).catch(() => false);
    check('...and their chronicle gains the fight they have just had, as it is read',
        gained, `${told} -> ${await lines()} line(s)`);

    // And follows it down, the way a chat box does: the line that just arrived is the one on screen.
    // `hidden` is asserted too, or a box nothing overflows would pass this by having nowhere to go.
    const log = await watcher.evaluate(() => {
        const body = document.querySelector('#chronicle .panel-body');
        const ground = (el) => { const s = getComputedStyle(el); return `${s.backgroundColor} ${s.backgroundImage}`; };
        return {
            hidden: body.scrollHeight - body.clientHeight, at: body.scrollTop,
            ground: ground(body) === ground(body.querySelector('ol.chronicle li:last-child')),
        };
    });
    check('...and follows it down without the reader scrolling',
        log.hidden > 0 && log.hidden - log.at <= 2,
        `${log.hidden}px scrolled away, sitting at ${log.at}`);

    // How far a box CAN be scrolled is a rounded figure, so it comes to rest a fraction off its
    // last entry however it is asked to — measured, snapped, reversed, they all land on the same
    // number. The strip that leaves is the scrollport's own ground, which is why it carries the
    // ground of whatever it ends on: there is then nothing of a different colour to show.
    check('...with nothing of another colour showing beneath the last of them', log.ground);

    // The board coalesces its refreshes over half a second, so the fight above can still be in
    // flight. Everything below compares one row read twice, and two readers straddling that window
    // would be comparing two different moments of a live game.
    await watcher.goto(`${BASE}/highscores`, { waitUntil: 'domcontentloaded' });
    await connected(watcher);
    await xpClimbedPast(watcher, fought);

    await watcher.goto(`${BASE}/`, { waitUntil: 'domcontentloaded' });
    await connected(watcher);
    check('...and going home offers them a character of their own',
        await watcher.locator('#main input[name="name"]').count() === 1);

    // ---- the same instant, read from two different clocks ------------------------------------
    // The server stores an instant and knows nothing about where anyone is, so the conversion has
    // to happen in the browser. Two contexts, two timezones, one row.
    const stampIn = async (timezoneId) => {
        const page = await (await browser.newContext({ timezoneId })).newPage();
        await page.goto(`${BASE}/highscores`, { waitUntil: 'domcontentloaded' });
        await connected(page);
        const cell = page.locator('#main table.data-table tbody tr td').last();
        await page.waitForFunction(
            () => document.querySelector('#main table.data-table tbody tr td:last-child time'),
            null, { timeout: 6000 });
        return {
            shown: (await cell.textContent()).trim(),
            iso: await cell.locator('time').getAttribute('datetime'),
            // What that instant IS in this timezone, computed by the browser itself.
            expected: await page.evaluate((iso) => {
                const d = new Date(iso), p = (n) => String(n).padStart(2, '0');
                return `${p(d.getDate())}/${p(d.getMonth() + 1)}/${String(d.getFullYear()).slice(-2)}`
                    + `, ${p(d.getHours())}:${p(d.getMinutes())}`;
            }, await cell.locator('time').getAttribute('datetime')),
        };
    };

    const tokyo = await stampIn('Asia/Tokyo');
    const la = await stampIn('America/Los_Angeles');

    check('a stamp is rendered in the reader\'s own timezone', tokyo.shown === tokyo.expected,
        `${tokyo.shown} vs ${tokyo.expected}`);
    check('...and in the other reader\'s, from the same instant',
        la.shown === la.expected && tokyo.iso === la.iso, `${la.shown} vs ${la.expected}`);
    check('...so two clocks disagree about one moment, as they should',
        tokyo.shown !== la.shown, `Tokyo ${tokyo.shown} · LA ${la.shown}`);

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
