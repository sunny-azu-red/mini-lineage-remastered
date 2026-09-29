/**
 * The Halls, live. The other two drive a single browser, so a board that refreshed only for
 * whoever caused the change would pass them both. Two contexts here means two session cookies and
 * two players, and it watches one player's page move because of what the OTHER one did.
 */
import { chromium } from 'playwright';
import { readWhole } from './helpers.mjs';

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

    // On a phone the Chronicle stacks under the record and folds, so a reader asks for it first.
    check('...its Chronicle folded under the record, on a phone',
        await watcher.locator('#chronicle .panel-body').isHidden());
    await watcher.click('#chronicle .panel-toggle');
    check('...until its own header opens it', await watcher.locator('#chronicle .panel-body').isVisible());

    // The chronicle is ADDED to while it is being read, never re-read: the reader keeps the
    // entries it already has. Dice-proof — the line is added whether that blow lands or kills.
    const lines = () => watcher.locator('#chronicle-log li').count();
    const newest = () => watcher.locator('#chronicle-log li').first().getAttribute('id');
    // Told by the newest entry changing, never by the count: at the present the oldest goes as it lands.
    const arrivedOver = (top) => watcher.waitForFunction(
        (top) => document.querySelector('#chronicle-log li')?.id !== top,
        top, { timeout: 8000 }).then(() => true).catch(() => false);
    // How many entries the run has, which the newest one's number says, however many are held.
    const written = () => watcher.evaluate(() => Number(document
        .querySelector('#chronicle-log .entry-head > span:last-child')?.textContent.replace('#', '') ?? 0));
    const told = await lines();
    const topBefore = await newest();
    await player.click('#main button[phx-click="fight"]');
    const gained = await arrivedOver(topBefore);
    check('...and their chronicle gains the fight they have just had, as it is read',
        gained, `${told} -> ${await lines()} line(s)`);

    // Newest first, so it arrives at the top, in view, with nothing having had to move for it.
    // `shown`, or a box of no height would pass by having nothing to show.
    const log = await watcher.evaluate(() => {
        const body = document.querySelector('#chronicle .panel-body');
        return { at: body.scrollTop, shown: body.clientHeight };
    });
    check('...on top, where a reader at the top already is',
        log.shown >= 100 && log.at === 0 && await newest() !== topBefore,
        `${log.shown}px shown, sitting at ${log.at}`);

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
    const topAtInn = await newest();
    await player.goto(`${BASE}/inn`, { waitUntil: 'domcontentloaded' });
    await connected(player);
    await player.selectOption('#main select[name="item_id"]', '0');
    await player.click('#main form[phx-submit="purchase"] button[type="submit"]');
    const reached = await arrivedOver(topAtInn);
    check('...and a purchase reaches them as a fight does, being just as much a deed', reached,
        `${heldBefore} -> ${await lines()} line(s)`);

    // The road above the panel is dated by the chronicle's newest entry, and moves with it.
    const dates = await watcher.evaluate(() => ({
        road: document.querySelector('#record-last')?.dateTime,
        last: document.querySelector('#chronicle-log li time')?.dateTime,
    }));
    check('...and the road is dated by that same entry, as it arrives', !!dates.road && dates.road === dates.last,
        `road ${dates.road} · last entry ${dates.last}`);

    // ---- a reader scrolled down to read is left there, and shown what arrived above -----------
    // Spiced Ale from here on: one row a purchase and no dice, so every arrival is certain.
    const logState = () => watcher.evaluate(() => {
        const body = document.querySelector('#chronicle .panel-body');
        const pill = document.querySelector('#chronicle .panel-unread');
        const marked = [...document.querySelectorAll('#chronicle-log [data-unread]')];
        const line = marked[0]?.getBoundingClientRect().bottom;
        return {
            top: body.scrollTop,
            pill: pill.hidden ? null : pill.textContent.trim(),
            marked: marked.map(li => `${li.id}:${li.dataset.unread}`),
            fromBottom: line === undefined ? null : body.getBoundingClientRect().bottom - line,
        };
    });
    // Brought into view first, as a reader would: a wheel over a point below the fold scrolls nothing.
    const overLog = async () => {
        await watcher.locator('#chronicle').scrollIntoViewIfNeeded();
        const box = await watcher.locator('#chronicle .panel-body').boundingBox();
        await watcher.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
    };
    const buyAle = async () => {
        const top = await newest();
        await player.selectOption('#main select[name="item_id"]', '0');
        await player.click('#main form[phx-submit="purchase"] button[type="submit"]');
        return arrivedOver(top);
    };

    await overLog();
    await watcher.mouse.wheel(0, 120);
    await watcher.waitForTimeout(350);
    const down = await logState();
    const reading = await watcher.evaluate(() => {
        const box = document.querySelector('#chronicle .panel-body').getBoundingClientRect();
        const entry = [...document.querySelectorAll('#chronicle-log li')].find(li => li.getBoundingClientRect().bottom > box.top);
        return { id: entry.id, offset: entry.getBoundingClientRect().top - box.top };
    });
    check('a reader who scrolls down the Chronicle is told of nothing while nothing has happened',
        down.top > 2 && !down.pill && !down.marked.length, JSON.stringify(down));

    const arrived = await buyAle();
    const held = await watcher.evaluate((id) =>
        document.getElementById(id).getBoundingClientRect().top
            - document.querySelector('#chronicle .panel-body').getBoundingClientRect().top, reading.id);
    check('...and is left on the line they were reading when an entry arrives above it',
        arrived && Math.abs(held - reading.offset) <= 1, `${reading.offset} -> ${held}`);
    const first = await newest();
    let away = await logState();
    check('...with the line drawn under it, where their reading left off',
        away.marked.join() === `${first}:1`, away.marked.join());
    check('...and a pill saying how much arrived', away.pill === '👁️ 1 new entry', away.pill);

    // Until the batch is taller than the box, so the jump has somewhere to land short of the top.
    let batch = 1;
    const outgrown = () => watcher.evaluate(() => {
        const body = document.querySelector('#chronicle .panel-body');
        const line = document.querySelector('#chronicle-log [data-unread]')?.getBoundingClientRect().bottom ?? 0;
        return line - document.getElementById('chronicle-log').getBoundingClientRect().top > 1.5 * body.clientHeight;
    });
    while (batch < 15 && !(await outgrown()))
        if (await buyAle()) batch++;
    away = await logState();
    check('...the line staying under the first of them as more arrive, counting the batch',
        away.marked.join() === `${first}:${batch}`, `${away.marked.join()} after ${batch}`);
    check('...and so does the pill', away.pill === `👁️ ${batch} new entries`, away.pill);

    await watcher.click('#chronicle .panel-unread');
    const jumped = await logState();
    check('the pill takes them back to where they left off, the line on the bottom edge of the box',
        jumped.fromBottom !== null && Math.abs(jumped.fromBottom - 24) <= 1, JSON.stringify(jumped));
    check('...counting only what is still above them', /^👁️ \d+ more above$/.test(jumped.pill ?? ''), jumped.pill);

    await watcher.click('#chronicle .panel-unread');
    const caught = await logState();
    check('...and a second click takes them up to the newest, with nothing left to tell',
        caught.top === 0 && !caught.pill && !caught.marked.length, JSON.stringify(caught));

    const topNow = await newest();
    await buyAle();
    const following = await logState();
    check('...and from there the newest is always in view again',
        following.top === 0 && !following.pill && !following.marked.length && await newest() !== topNow,
        JSON.stringify(following));

    // ---- a tab in the background is away too, and comes back to the view it left --------------
    const topEntry = await newest();
    const at = () => watcher.evaluate((id) => document.getElementById(id).getBoundingClientRect().top
        - document.querySelector('#chronicle .panel-body').getBoundingClientRect().top, topEntry);
    const wasAt = await at();
    await watcher.evaluate(() => {
        Object.defineProperty(document, 'hidden', { configurable: true, get: () => window.__hidden });
        window.__hidden = true;
    });
    for (let n = 0; n < 3; n++) await buyAle();
    await watcher.evaluate(() => {
        window.__hidden = false;
        document.dispatchEvent(new Event('visibilitychange'));
        delete document.hidden;
    });
    const returned = await logState();
    // Half a pixel a patch: a scroll offset is whole pixels and a row here is not.
    check('a reader whose tab was in the background comes back to the line they left',
        Math.abs((await at()) - wasAt) <= 2, `${wasAt} -> ${await at()}`);
    check('...shown what arrived meanwhile, the line just above them',
        returned.pill === '👁️ 3 new entries' && returned.marked.length === 1, JSON.stringify(returned));
    await watcher.click('#chronicle .panel-unread');
    await watcher.click('#chronicle .panel-unread').catch(() => {});

    // ---- and a long one arrives a page at a time -----------------------------------------------
    // The suites' page is ten (config/e2e.exs), so this outgrows it twice over.
    while (await written() <= 21)
        if (!(await buyAle())) break;

    // Nothing about the last visit is kept: a refresh opens on the fold, and then on the newest.
    await watcher.reload({ waitUntil: 'domcontentloaded' });
    await connected(watcher);
    check('a refreshed Chronicle is folded again on a phone, whatever the reader left it as',
        await watcher.locator('#chronicle .panel-body').isHidden());
    await watcher.click('#chronicle .panel-toggle');
    check('...and opens on its newest entry', (await logState()).top === 0);

    const firstPage = await lines();
    check('...holding only its newest page, with an older one to ask for',
        firstPage === 10 && await watcher.locator('#chronicle-log[data-older-than]').count() === 1,
        `${firstPage} entries`);

    // One in and one out, so a reader following a fight does not see the scrollbar jump.
    const followed = await buyAle();
    check('...and a reader there lets the oldest go as the newest lands, holding one page',
        followed && await lines() === firstPage, `${await lines()} entries`);

    const deepest = await watcher.locator('#chronicle-log li').last().getAttribute('id');
    await overLog();
    await watcher.mouse.wheel(0, 100000);
    const paged = await watcher.waitForFunction(
        (had) => document.querySelectorAll('#chronicle-log li').length > had,
        firstPage, { timeout: 8000 }).then(() => true).catch(() => false);
    check('...and scrolling towards its end hands over the page before it', paged,
        `${firstPage} -> ${await lines()} entries`);

    // The page goes on below the reader, so the entry they scrolled down to stays where it was.
    const kept = await watcher.evaluate((id) => {
        const box = document.querySelector('#chronicle .panel-body').getBoundingClientRect();
        const entry = document.getElementById(id).getBoundingClientRect();
        return { inView: entry.bottom > box.top && entry.top < box.bottom,
                 unread: !document.querySelector('#chronicle .panel-unread').hidden,
                 marked: document.querySelectorAll('#chronicle-log [data-unread]').length };
    }, deepest);
    check('...without moving the reader off the line they had reached', kept.inView);
    check('...or claiming anything arrived above', !kept.unread && !kept.marked);

    const whole = await readWhole(watcher);
    check('...and so on back to its Beginning, where it stops asking',
        whole && await watcher.locator('#chronicle-log li').last().getAttribute('class') === 'start'
            && await watcher.locator('#chronicle-log[data-older-than]').count() === 0,
        `${await lines()} entries`);

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
    // to happen in the browser. Two contexts, two timezones, one row. A recent row says its age,
    // which is the same everywhere, so the claim is on the tooltip, which always names the instant.
    const stampIn = async (timezoneId) => {
        const page = await (await browser.newContext({ timezoneId })).newPage();
        await page.goto(`${BASE}/highscores`, { waitUntil: 'domcontentloaded' });
        await connected(page);
        const stamp = page.locator('#main table.data-table tbody tr td:last-child time').first();
        await stamp.waitFor({ timeout: 6000 });
        const iso = await stamp.getAttribute('datetime');
        return {
            shown: await stamp.getAttribute('title'),
            iso,
            // What that instant IS in this timezone, computed by the browser itself.
            expected: await page.evaluate((iso) => {
                const d = new Date(iso), p = (n) => String(n).padStart(2, '0'), h = d.getHours();
                const month = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.getMonth()];
                return `${d.getDate()} ${month} ${d.getFullYear()}, ${h % 12 || 12}:${p(d.getMinutes())} ${h < 12 ? 'am' : 'pm'}`;
            }, iso),
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

    check('a stamp is dated in the reader\'s own timezone', tokyo.shown === tokyo.expected,
        `${tokyo.shown} vs ${tokyo.expected}`);
    check('...and in the other reader\'s, from the same instant',
        la.shown === la.expected && tokyo.iso === la.iso, `${la.shown} vs ${la.expected}`);
    check('...so two clocks disagree about one moment, as they should',
        tokyo.shown !== la.shown, `Tokyo ${tokyo.shown} · LA ${la.shown}`);

    // ---- a stamp ages on the page, from the frame the server drew ------------------------------
    // Three hours fast: the hook must age from the server's clock, or a deed done a moment ago
    // reads "3h ago" the instant it takes over. The clock is Playwright's, so no assertion waits on
    // a real minute passing; the one real interval assumed is under a minute from deed to read.
    const aging = await (await browser.newContext()).newPage();
    await aging.clock.install({ time: Date.now() + 3 * 3_600_000 });
    const boughtAt = Date.now() - 1000;
    await player.selectOption('#main select[name="item_id"]', '0');
    await player.click('#main form[phx-submit="purchase"] button[type="submit"]');
    await aging.goto(`${BASE}${href}`, { waitUntil: 'domcontentloaded' });
    await connected(aging);
    await aging.waitForFunction((since) =>
        Date.parse(document.querySelector('#chronicle-log li time')?.dateTime ?? 0) >= since,
        boughtAt, { timeout: 8000, polling: 100 }).catch(() => {});
    const labels = () => aging.evaluate(() => ({
        head: document.querySelector('#chronicle-log li time')?.textContent,
        road: document.querySelector('#record-last')?.textContent,
    }));

    let said = await labels();
    check('a deed a moment old reads as just now, whatever the reader\'s clock says',
        said.head === 'just now' && said.road === 'just now', JSON.stringify(said));

    await aging.clock.fastForward(2 * 60_000);
    said = await labels();
    check('...and ages on the page with nobody asking, short in the Chronicle and long in the road',
        said.head === '2m ago' && said.road === '2 minutes ago', JSON.stringify(said));

    await aging.clock.fastForward(3 * 3_600_000);
    said = await labels();
    check('...into hours', said.head === '3h ago' && said.road === '3 hours ago', JSON.stringify(said));

    // Past the cap both keep the time, a log's after a comma and a sentence's after the "at" it
    // needs, and the sentence names its month in full.
    await aging.clock.fastForward(7 * 24 * 3_600_000);
    said = await labels();
    check('...and past a week names the date instead',
        /^\d{1,2} [A-Z][a-z]{2}, \d{1,2}:\d\d [ap]m$/.test(said.head)
            && /^on \d{1,2} (January|February|March|April|May|June|July|August|September|October|November|December) at \d{1,2}:\d\d [ap]m$/.test(said.road),
        JSON.stringify(said));
    await aging.context().close();

    // ---- a sorted board, kept by the reader and kept up by the pushes -------------------------
    // A second run, born after everything LiveOne has done, so it is the one seen last.
    const second = await (await browser.newContext()).newPage();
    second.on('console', (m) => m.type() === 'error' && consoleErrors.push(m.text()));
    await second.goto(BASE, { waitUntil: 'domcontentloaded' });
    await connected(second);
    await second.fill('#main input[name="name"]', 'LiveTwo');
    await second.selectOption('#main select[name="race_id"]', '0');
    await second.click('#main button[type="submit"]');
    await second.waitForSelector('#screen[data-screen="home"]', { timeout: 8000 });

    await watcher.goto(`${BASE}/highscores`, { waitUntil: 'domcontentloaded' });
    await connected(watcher);
    const board = () => watcher.evaluate(() => ({
        names: [...document.querySelectorAll('#halls-rows tr td.name a')].map(a => a.textContent.trim()),
        stamps: [...document.querySelectorAll('#halls-rows tr')].map(tr => tr.dataset.stamp),
        sorted: [...document.querySelectorAll('#halls-table th[aria-sort]')]
            .map(th => `${th.textContent.trim()}:${th.getAttribute('aria-sort')}`),
        reset: !!document.querySelector('#halls-table-reset'),
    }));
    const boardIs = (names) => watcher.waitForFunction((want) =>
        [...document.querySelectorAll('#halls-rows tr td.name a')].map(a => a.textContent.trim()).join() === want,
        names.join(), { timeout: 8000 }).then(() => true).catch(() => false);
    const sortBy = (key) => watcher.click(`#halls-table button[phx-value-key="${key}"]`);

    await boardIs(['LiveOne', 'LiveTwo']);
    let halls = await board();
    check('the Halls open on the ranking, no column sorted and nothing to reset',
        halls.names.join() === 'LiveOne,LiveTwo' && !halls.sorted.length && !halls.reset, JSON.stringify(halls));

    const focused = () => watcher.evaluate(() => {
        const el = document.activeElement;
        return el?.matches('.sort, .reset-sort') ? el.getAttribute('phx-value-key') ?? el.id : null;
    });
    check('...nor is a header handed focus on arrival, where Space would sort it', await focused() === null);

    await sortBy('date');
    const byDate = await boardIs(['LiveTwo', 'LiveOne']);
    halls = await board();
    check('...focus staying on the header clicked, not the reset that appeared',
        await focused() === 'date', await focused());
    check('...and a click on Last Sighted puts whoever was seen last on top',
        byDate && halls.stamps[0] > halls.stamps[1] && halls.sorted.join() === 'Last Sighted:descending' && halls.reset,
        JSON.stringify(halls));

    // A filter goes somewhere and the reset does something, so one is a link and one a button,
    // and the variant alone decides how either looks. A link's own colour had been winning.
    const FILTER = '.action-links a.btn-secondary:not(.active)';
    const lookOf = (selector) => watcher.evaluate((sel) => {
        const style = getComputedStyle(document.querySelector(sel));
        return `${style.color} ${style.transitionProperty} ${style.textDecorationLine}`;
    }, selector);
    const atRest = [await lookOf(FILTER), await lookOf('#halls-table-reset')];
    await watcher.hover(FILTER);
    const filterHover = await lookOf(FILTER);
    await watcher.hover('#halls-table-reset');
    const hovered = [filterHover, await lookOf('#halls-table-reset')];
    check('...the filters beside it drawn as the same secondary button, links though they are',
        atRest[0] === atRest[1] && hovered[0] === hovered[1], JSON.stringify({ atRest, hovered }));

    // The pointer is still over the reset, so its ring is also checked against its own hover.
    const ringOf = (selector) => watcher.evaluate(async (sel) => {
        const el = document.querySelector(sel);
        el.focus();
        await Promise.all(el.getAnimations().map((a) => a.finished));
        const style = getComputedStyle(el);
        el.blur();
        return style.borderTopColor === style.color || `${style.color} ringed ${style.borderTopColor}`;
    }, selector);
    const rings = [await ringOf('#halls-table-reset'), await ringOf(FILTER)];
    check('...and focused, ringed in their own text\'s colour rather than the primary\'s gold',
        rings.every((ring) => ring === true), JSON.stringify(rings));

    // Ale, never a fight: a purchase is always a row, and nothing about it is the dice's.
    await player.selectOption('#main select[name="item_id"]', '0');
    await player.click('#main form[phx-submit="purchase"] button[type="submit"]');
    check('...and whoever plays next rises to the top as they do, the sort outliving the push',
        await boardIs(['LiveOne', 'LiveTwo']) && (await board()).sorted.join() === 'Last Sighted:descending');

    await watcher.reload({ waitUntil: 'domcontentloaded' });
    await connected(watcher);
    halls = await board();
    check('...and a refresh opens on the sort the reader left',
        halls.names.join() === 'LiveOne,LiveTwo' && halls.sorted.join() === 'Last Sighted:descending', JSON.stringify(halls));

    await sortBy('date');
    check('...a second click reverses it', await boardIs(['LiveTwo', 'LiveOne'])
        && (await board()).sorted.join() === 'Last Sighted:ascending');
    await sortBy('date');
    await boardIs(['LiveOne', 'LiveTwo']);
    halls = await board();
    check('...and a third returns to the ranking, taking the reset away with it',
        !halls.sorted.length && !halls.reset, JSON.stringify(halls));

    await watcher.reload({ waitUntil: 'domcontentloaded' });
    await connected(watcher);
    check('...and a refresh forgets the sort that was undone', !(await board()).sorted.length);

    await sortBy('name');
    await watcher.waitForSelector('#halls-table-reset', { timeout: 8000 });
    await watcher.click('#halls-table-reset');
    await watcher.waitForSelector('#halls-table-reset', { state: 'detached', timeout: 8000 });
    halls = await board();
    check('Reset Sort puts the ranking back and takes itself away',
        halls.names.join() === 'LiveOne,LiveTwo' && !halls.sorted.length, JSON.stringify(halls));

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
