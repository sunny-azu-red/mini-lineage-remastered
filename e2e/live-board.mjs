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

// A fight can end in an ambush, which pins the fighter to the Battleground and refuses any walk
// away from it: the dice's call, so it is fought out before a walk, never hoped against.
const fightOffAmbush = async (page) => {
    for (let fights = 0; fights < 20; fights++) {
        const screen = await page.evaluate(() => ({ ...document.querySelector('#screen')?.dataset }));
        if (screen.ambushed !== 'true' || screen.dead === 'true') return;

        await page.click('#main button[phx-click="fight"]');
        await page.waitForFunction((had) => {
            const now = document.querySelector('#screen')?.dataset;
            return now && (Number(now.battles ?? 0) > had || now.dead === 'true');
        }, Number(screen.battles ?? 0), { timeout: 8000 });
    }
};

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

    // One more before the record is opened, so the Chronicle outgrows its box however the lines read.
    await player.click('#main button[phx-click="fight"]');
    await player.waitForFunction(
        () => Number(document.querySelector('#screen')?.dataset.battles ?? 0) > 1,
        null, { timeout: 8000 }).catch(() => {});

    const fought = await boardXp(watcher);

    // A stranger's row is a link, and following it must never adopt their character.
    const href = await watcher.getAttribute('#main table.data-table a', 'href');
    check('...at a link to that run\'s own record', /^\/character\/\S+$/.test(href ?? ''), href ?? '');

    // Read at phone width from here on, where the entries overflow the Chronicle's box and following
    // it down is observable at all.
    await watcher.setViewportSize({ width: 320, height: 800 });
    await watcher.goto(`${BASE}${href}`, { waitUntil: 'domcontentloaded' });
    await connected(watcher);
    const record = (await watcher.textContent('#main'))?.replace(/\s+/g, ' ') ?? '';
    check('...showing a stranger\'s stats and their chronicle so far',
        /LiveOne/.test(record) && /last carried/.test(record), record.slice(0, 90));
    check('...while the watcher stays a visitor, not that character',
        await watcher.evaluate(() => document.querySelector('#screen')?.dataset.started) === 'false');

    // The Chronicle opens shut, so a reader watching one has to ask for it first.
    await watcher.click('#chronicle .panel-toggle');

    // The chronicle is APPENDED to while it is being read, never re-read: the reader keeps the
    // entries it already has. Dice-proof — the line is added whether that blow lands or kills.
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
        return { hidden: body.scrollHeight - body.clientHeight, at: body.scrollTop };
    });
    check('...and follows it down without the reader scrolling',
        log.hidden > 0 && log.hidden - log.at <= 2,
        `${log.hidden}px scrolled away, sitting at ${log.at}`);

    // And rests somewhere the reader's own scrolling agrees with. A box can be put a fraction past
    // its content from script, but a wheel goes through the compositor, which corrects it — so a
    // pin that overshoots shows up as the log jumping UP under the first flick DOWN.
    const box = await watcher.locator('#chronicle .panel-body').boundingBox();
    await watcher.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
    await watcher.mouse.wheel(0, 120);
    await watcher.waitForTimeout(350);
    const settled = await watcher.evaluate(() =>
        document.querySelector('#chronicle .panel-body').scrollTop);
    check('...and stays put when the reader scrolls further down, rather than jumping up',
        settled >= log.at, `${log.at} -> ${settled}`);

    // ---- what is riding on the run, explained rather than drawn -------------------------------
    // The header wears these as emoji, which a phone can neither hover nor read; the record spells
    // them out. The player is standing in a combat zone, so that is the aura the watcher must see.
    const effects = () => watcher.textContent('#record-effects').then(t => t.replace(/\s+/g, ' '));
    const combat = await effects();
    check('...and what is riding on the run, spelled out rather than left to a hover',
        /In Combat/.test(combat) && /Steel is out/.test(combat), combat.slice(0, 80));

    // And they come and go on their own: walking out of the fray drops the combat aura for a
    // resting one, and the watcher is told without asking for anything.
    await fightOffAmbush(player);
    await player.goto(`${BASE}/`, { waitUntil: 'domcontentloaded' });
    await connected(player);
    const swapped = await watcher.waitForFunction(
        () => /Resting/.test(document.querySelector('#record-effects')?.textContent ?? ''),
        null, { timeout: 15000 }).then(() => true).catch(() => false);
    check('...and change as the run does, with the reader asking for nothing', swapped,
        (await effects()).slice(0, 80));

    // A deed that is not a fight has to reach a watcher too: a purchase moves neither the battle
    // tally nor the last fight.
    const heldBefore = await lines();
    await player.goto(`${BASE}/inn`, { waitUntil: 'domcontentloaded' });
    await connected(player);
    await player.selectOption('#main select[name="item_id"]', '0');
    await player.click('#main form[phx-submit="purchase"] button[type="submit"]');
    const reached = await watcher.waitForFunction(
        (had) => document.querySelectorAll('#main ol.chronicle li').length > had,
        heldBefore, { timeout: 8000 }).then(() => true).catch(() => false);
    check('...and a purchase reaches them as a fight does, being just as much a deed', reached,
        `${heldBefore} -> ${await lines()} line(s)`);

    // The road above the panel is dated by the chronicle's last entry, and moves with it.
    const dates = await watcher.evaluate(() => ({
        road: document.querySelector('#record-last')?.dateTime,
        last: [...document.querySelectorAll('#main ol.chronicle li time')].at(-1)?.dateTime,
    }));
    check('...and the road is dated by that same entry, as it arrives', !!dates.road && dates.road === dates.last,
        `road ${dates.road} · last entry ${dates.last}`);

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

    // Read until both land on the same instant. A row's date moves whenever its log does — a buff
    // lapsing counts — and the board coalesces its refreshes, so two page loads a moment apart can
    // straddle one. The claim is one instant rendered twice, not that nothing ever moves.
    let tokyo, la;
    for (let tries = 0; tries < 5; tries++) {
        tokyo = await stampIn('Asia/Tokyo');
        la = await stampIn('America/Los_Angeles');
        if (tokyo.iso === la.iso) break;
    }

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
