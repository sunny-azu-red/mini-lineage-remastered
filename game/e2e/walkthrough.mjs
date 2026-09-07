/**
 * Drives the real game in a real browser. Unit tests and jsdom cannot see CSP enforcement, a
 * stale bundle, or a background push wiping the panel — every browser-only bug in this project
 * lived in exactly that gap.
 *
 * Usage: start the isolated server (`game/e2e/serve.sh`), then
 *   LD_LIBRARY_PATH=~/.local/lib/playwright-deps node game/e2e/walkthrough.mjs
 */
import { chromium } from 'playwright';

const BASE = process.env.E2E_BASE_URL ?? 'http://localhost:4002';
const TICK_MS = 6000; // the regen tick is 5s; allow a margin

const failures = [];
const check = (label, ok, detail = '') => {
    console.log(`${ok ? '✅' : '❌'} ${label}${detail ? ` — ${detail}` : ''}`);
    if (!ok)
        failures.push(label);
};

const browser = await chromium.launch();
const context = await browser.newContext();

// Records every note the page actually plays. Web Audio produces no output to assert on, so the
// synth is verified by the graph it builds — the same idea as the reference's sound trace test.
await context.addInitScript(() => {
    window.__notes = [];
    const create = AudioContext.prototype.createOscillator;
    AudioContext.prototype.createOscillator = function () {
        const osc = create.call(this);
        const start = osc.start.bind(osc);
        osc.start = (when) => {
            window.__notes.push(osc.type);
            return start(when);
        };
        return osc;
    };
});

const page = await context.newPage();

const consoleErrors = [];
const failedRequests = [];
page.on('console', m => { if (m.type() === 'error') consoleErrors.push(m.text()); });
page.on('pageerror', e => consoleErrors.push(`pageerror: ${e.message}`));
page.on('requestfailed', r => {
    // Google Fonts may be unreachable offline; that is not the app's fault.
    if (r.url().startsWith(BASE))
        failedRequests.push(`${r.method()} ${r.url()} :: ${r.failure()?.errorText}`);
});

/** The character's live state, read off the one element that mirrors it. */
const state = async () => {
    const el = page.locator('#screen');
    const raw = await el.evaluate(node => ({ ...node.dataset }));
    return {
        screen: raw.screen,
        started: raw.started === 'true',
        dead: raw.dead === 'true',
        ambushed: raw.ambushed === 'true',
        level: raw.level ? Number(raw.level) : null,
        health: raw.health ? Number(raw.health) : null,
        maxHealth: raw.maxHealth ? Number(raw.maxHealth) : null,
        adena: raw.adena ? Number(raw.adena) : null,
    };
};

const onScreen = (name) => page.waitForSelector(`#screen[data-screen="${name}"]`, { timeout: 8000 });

/**
 * Clicks Fight and waits for the result to actually land. A fixed sleep raced the round trip: a
 * FATAL fight patches to the death screen while a stale read still says alive, and the next click
 * then hunts a Fight button that no longer exists. A fatal fight is not counted as a battle, so
 * the battle counter alone is not enough — either signal ends the wait.
 */
async function fight() {
    await page.waitForSelector('.phx-connected', { timeout: 8000 });
    const before = await page.getAttribute('#screen', 'data-battles');
    // Matched on the event, not the label: an ambush relabels this button to the narrative's own
    // prompt ("Face your Foe!"), which shares no words with the ordinary one.
    await page.click('#main button[phx-click="fight"]', { timeout: 8000 });
    await page.waitForFunction(
        (prev) => {
            const el = document.querySelector('#screen');
            return !!el && (el.dataset.screen === 'death' || el.dataset.battles !== prev);
        },
        before,
        { timeout: 8000 },
    );
}

/**
 * Travels via the Town form, which is how a player actually moves.
 *
 * Waits for the socket first: an unconnected LiveView submits the form natively, and the real
 * navigation that follows is then aborted the moment the socket comes up. That produced a
 * `net::ERR_ABORTED` against the failed-request assertion perhaps one run in five.
 */
/** Returns to Town by clicking the banner, the way the header link works in the game. */
async function goHome() {
    await page.click('#header-link');
    await onScreen('home');
}

/**
 * Buys one item and waits for the purse to actually move.
 *
 * Waiting for `#main .alert` instead returns immediately — the previous purchase's alert is still
 * on screen — so the next iteration reads stale adena and tries to buy what it can no longer
 * afford. Returns false when the purchase was refused.
 */
async function buy(itemId) {
    const before = await page.getAttribute('#screen', 'data-adena');
    await page.selectOption('#main select[name="item_id"]', String(itemId), { timeout: 5000 });
    await page.click('#main form[phx-submit="purchase"] button[type="submit"]');

    return page
        .waitForFunction(
            (prev) => document.querySelector('#screen')?.dataset.adena !== prev,
            before,
            { timeout: 5000 },
        )
        .then(() => true)
        .catch(() => false);
}

/** Leaves a shop through its own "🚪 Home Town" option rather than by navigating away. */
async function leaveShop() {
    await page.selectOption('#main select[name="item_id"]', '', { timeout: 5000 });
    await page.click('#main form[phx-submit="purchase"] button[type="submit"]');
    await onScreen('home');
}

async function travel(to) {
    await page.waitForSelector('.phx-connected', { timeout: 8000 });
    await onScreen('home');

    try {
        await page.selectOption('#main select[name="to"]', to, { timeout: 5000 });
    } catch {
        const ds = await page.locator('#screen').evaluate(n => JSON.stringify({ ...n.dataset }));
        const controls = await page.locator('#main select, #main button').allTextContents();
        throw new Error(`no travel form on the way to "${to}". screen=${ds} controls=${JSON.stringify(controls)}`);
    }

    await page.click('#main form[phx-submit="navigate"] button[type="submit"]');
    // Travelling to the Battleground fights on arrival, which can kill outright.
    try {
        await page.waitForFunction(
            (dest) => {
                const screen = document.querySelector('#screen')?.dataset.screen;
                return screen === dest || screen === 'death';
            },
            to,
            { timeout: 8000 },
        );
    } catch {
        // A LiveView that crashed remounts on the screen it started from, so say which trip
        // failed rather than reporting a bare timeout.
        throw new Error(`travel to "${to}" never arrived — still on "${(await state()).screen}"`);
    }
}

try {
    // Never `networkidle`: the LiveView websocket stays open, so it never settles.
    await page.goto(BASE, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('.phx-connected', { timeout: 8000 });

    // ---- the stylesheet actually applied, not merely 200'd -----------------------------------
    const bg = await page.locator('body').evaluate(el => getComputedStyle(el).backgroundColor);
    const font = await page.locator('.header-title').evaluate(el => getComputedStyle(el).fontFamily);
    check('the carried-over CSS is applied', bg !== 'rgba(0, 0, 0, 0)', `body background ${bg}`);
    check('...including the display font', /Cinzel|Silkscreen/i.test(font), font);
    check('LiveView connects through the CSP', true);

    // The footer names the running build, flagged when it is not a release.
    const footer = await page.textContent('#copyright');
    check('the footer names the running build', /development/.test(footer ?? ''), footer?.trim());
    check('...and flags it as a debug build', await page.locator('#copyright .version-debug').count() === 1);

    const cookie = (await context.cookies()).find(c => c.name === '_mini_lineage_key');
    check('the session cookie is httpOnly', cookie?.httpOnly === true);
    check('...and sameSite Lax', cookie?.sameSite === 'Lax', String(cookie?.sameSite));

    // ---- access policy: a visitor cannot walk into the game -----------------------------------
    // The `page.goto` calls from here on are deliberate: a TYPED URL is the thing under test, and
    // there is no in-app link to these screens for a visitor to click. Everywhere else the
    // walkthrough clicks, because a route reached only by URL is a route that never gets tested —
    // travelling to the Battleground crashed the LiveView while its URL worked perfectly.
    await page.goto(`${BASE}/battle`, { waitUntil: 'domcontentloaded' });
    check('a typed URL into Battle bounces a visitor to Game Start', (await state()).screen === 'start');
    await page.goto(`${BASE}/death`, { waitUntil: 'domcontentloaded' });
    check('...and so does the death screen', (await state()).screen === 'start');
    await page.goto(`${BASE}/races`, { waitUntil: 'domcontentloaded' });
    check('...but Chronicles of Ancestry is public', (await state()).screen === 'races');

    // ---- the error screen is a real, styled screen ---------------------------------------------
    await page.goto(`${BASE}/error`, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('.phx-connected', { timeout: 8000 });
    check('the error screen is routable and styled', (await state()).screen === 'error');
    check('...and offers a way out',
        await page.locator('#main a:has-text("Return to safer lands")').count() === 1);

    // The reference served index.html for every non-API GET and its router resolved an unknown path
    // to Home, rewriting the address bar. The game owns every URL; there is no 404 page to reach.
    const unknown = await page.goto(`${BASE}/no-such-road`, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('.phx-connected', { timeout: 8000 });
    check('an unknown URL serves the game, not an error', unknown?.status() === 200, String(unknown?.status()));
    check('...resolving to the screen a visitor belongs on', (await state()).screen === 'start');
    check('...and correcting the address bar', new URL(page.url()).pathname === '/', page.url());

    // ---- create a character -------------------------------------------------------------------
    await page.goto(BASE, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('.phx-connected', { timeout: 8000 });
    await page.fill('#main input[name="name"]', 'BrowserBot');
    await page.selectOption('#main select[name="race_id"]', '1'); // Orc: 150 HP, survives a while
    await page.click('#main button[type="submit"]');
    await onScreen('home');

    const born = await state();
    const startNotes = await page.evaluate(() => window.__notes.slice());
    check('creating a character plays the start fanfare', startNotes.length === 4,
        `notes: ${JSON.stringify(startNotes)}`);
    check('...as three triangles and a square', startNotes.join(',') === 'triangle,triangle,triangle,square',
        startNotes.join(','));

    check('creating a character lands on Town', born.screen === 'home');
    check('...at full health', born.health === born.maxHealth, `${born.health}/${born.maxHealth}`);
    check('...with the Orc purse', born.adena === 250, String(born.adena));
    check('the sidebar appears alongside it', await page.locator('#sidebar').count() === 1);

    // ---- a flash belongs to its action, and to nothing after it -------------------------------
    check('creating a character flashes its welcome',
        /You have chosen the/.test(await page.textContent('#main .alert') ?? ''));

    // Panel heading and document title, both carried over from the reference verbatim.
    check('Town is headed "Home Town"',
        (await page.textContent('#main .header-name'))?.trim() === 'Home Town',
        await page.textContent('#main .header-name'));
    check('...and the document title names the screen',
        await page.title() === 'Mini Lineage - Home Town', await page.title());
    check('the panel takes focus so the game plays from the keyboard',
        await page.evaluate(() => document.activeElement?.tagName) === 'SELECT',
        await page.evaluate(() => document.activeElement?.tagName));

    // ---- the action button answers to the selection ---------------------------------------------
    const actionButton = async () => ({
        label: (await page.textContent('#main form button'))?.trim(),
        cls: await page.getAttribute('#main form button', 'class'),
    });
    check('Town offers to Travel before anything is picked',
        (await actionButton()).label === 'Travel', JSON.stringify(await actionButton()));
    await page.selectOption('#main select[name="to"]', 'suicide');
    check('...and turns into Perish when Suicide is chosen',
        (await actionButton()).label === '⚰️ Perish', JSON.stringify(await actionButton()));
    await page.selectOption('#main select[name="to"]', 'inn');
    check('...and back to Travel for anywhere else',
        (await actionButton()).label === 'Travel', JSON.stringify(await actionButton()));

    // ---- the effect timer counts down locally --------------------------------------------------
    const timerText = () => page.textContent('#effects [data-effect-id="newbie_blessing"] .effect-timer');
    // Clicked last of the checks here: clicking it moves focus off the panel's own control.
    await page.click('#main .alert');
    await page.waitForTimeout(300);
    check('...which clicking does not dismiss', await page.locator('#main .alert').count() === 1);

    check('the Newbie Blessing shows a timer', /^\d+m?$/.test((await timerText()) ?? ''), await timerText());
    const remainingBefore = await page.getAttribute('#effects [data-effect-id="newbie_blessing"]', 'data-remaining-ms');
    check('...counted from a duration, never a server timestamp', Number(remainingBefore) <= 300000,
        `${remainingBefore}ms`);

    // ---- muting is a per-browser preference ----------------------------------------------------
    await page.click('#sound-toggle');
    check('muting flips the toggle', await page.textContent('#sound-toggle') === '🔇');
    const beforeMuted = (await page.evaluate(() => window.__notes.length));
    await page.click('#sound-toggle');
    check('unmuting flips it back', await page.textContent('#sound-toggle') === '🔊');
    check('...and the unmute chime is itself audible',
        (await page.evaluate(() => window.__notes.length)) > beforeMuted);

    // ---- a second tab follows along -------------------------------------------------------------
    const tab = await context.newPage();
    await tab.goto(BASE, { waitUntil: 'domcontentloaded' });
    await tab.waitForSelector('.phx-connected', { timeout: 8000 });
    check('a second tab sees the same character',
        await tab.getAttribute('#screen', 'data-health') === String(born.health));

    // ---- a living character is kept out of character creation ---------------------------------
    await page.goto(`${BASE}/statistics`, { waitUntil: 'domcontentloaded' });
    check('a living character is bounced off Statistics', (await state()).screen === 'home');

    // ---- travel and buy -----------------------------------------------------------------------
    await goHome();

    // ---- the board is reachable from Town's own prose link -------------------------------------
    await page.click('#main a[href="/highscores"]');
    await onScreen('highscores');
    check('Town links through to the Hall of Champions', (await state()).screen === 'highscores');

    // The race filters, clicked as a player would — including back to All, which is simply
    // /highscores with no race in the path and so is the one that can silently do nothing.
    const boardRows = () => page.locator('#main table.data-table tbody tr').count();
    const activeFilter = async () =>
        (await page.textContent('#main .action-links a.active'))?.replace(/\s+/g, ' ').trim();
    const allRows = await boardRows();
    check('the board opens on All', (await activeFilter())?.trim() === 'All', await activeFilter());

    await page.click('#main .action-links a:has-text("Elf") >> nth=0');
    await page.waitForFunction(() => location.pathname !== '/highscores', null, { timeout: 5000 });
    const elfRows = await boardRows();
    check('filtering to a race narrows the board',
        elfRows < allRows && (await activeFilter())?.includes('Elf'),
        `${allRows} rows -> ${elfRows}, active "${await activeFilter()}"`);
    check('...and a filter matching nobody says so rather than showing an empty table',
        elfRows > 0 || /The halls are silent/.test(await page.textContent('#main') ?? ''));

    await page.click('#main .action-links a:has-text("All")');
    await page.waitForFunction(() => location.pathname === '/highscores', null, { timeout: 5000 });
    check('...and All puts every race back',
        await boardRows() === allRows && (await activeFilter())?.trim() === 'All',
        `${await boardRows()} rows, active ${await activeFilter()}`);

    await page.click('#main .last a');
    await onScreen('home');

    await travel('inn');
    check('the Inn is headed "Inn"',
        (await page.textContent('#main .header-name'))?.trim() === 'Inn',
        await page.textContent('#main .header-name'));
    check('a shop offers to Return until something is picked',
        (await actionButton()).label === 'Return'
        && (await actionButton()).cls === 'btn btn-secondary', JSON.stringify(await actionButton()));
    check('the Inn hands focus to its own picker, not a hidden field',
        await page.evaluate(() => document.activeElement?.getAttribute('name')) === 'item_id',
        await page.evaluate(() => document.activeElement?.tagName + '/' + (document.activeElement?.getAttribute('name') ?? '')));
    const beforeMeal = await state();
    await page.selectOption('#main select[name="item_id"]', '0'); // Spiced Ale, 7 adena
    check('...and to Order once a dish is chosen',
        (await actionButton()).label === '🪙 Order' && (await actionButton()).cls === 'btn',
        JSON.stringify(await actionButton()));
    await page.click('#main form[phx-submit="purchase"] button[type="submit"]');
    await page.waitForSelector('#main .alert', { timeout: 8000 });
    // Scoped to #main: the sidebar's panels carry .panel-body too.
    const mealText = await page.textContent('#main .alert');
    check('ordering a meal reports back', /You have bought/.test(mealText), mealText?.trim().slice(0, 60));
    check('...and the purse reflects the spend', (await state()).adena === beforeMeal.adena - 7);

    // One-shot: it belongs to the purchase, not to wherever you wander next.
    await leaveShop();
    check('a flash does not survive leaving the screen',
        await page.locator('#main .alert').count() === 0,
        await page.textContent('#main .alert').catch(() => '(none)'));
    await travel('inn');

    await tab.waitForFunction(
        (expected) => document.querySelector('#screen')?.dataset.adena === expected,
        String(beforeMeal.adena - 7),
        { timeout: 8000 },
    ).then(() => check('the other tab sees the spend without acting', true))
     .catch(async () => check('the other tab sees the spend without acting', false,
        `tab adena ${await tab.getAttribute('#screen', 'data-adena')}`));
    await tab.close();

    await goHome();
    await travel('weapons');
    check('...and so does the Weapons Shop',
        await page.evaluate(() => document.activeElement?.getAttribute('name')) === 'item_id');
    await page.selectOption('#main select[name="item_id"]', '1'); // Elven Needle, 300 — unaffordable
    await page.click('#main form[phx-submit="purchase"] button[type="submit"]');
    await page.waitForSelector('#main .alert-danger', { timeout: 8000 });
    check('an unaffordable weapon is refused, not an error page',
        /do not have enough Adena/.test(await page.textContent('#main .alert-danger')));

    // ---- a background tick must not disturb the open panel ------------------------------------
    // Pick an option and leave it UNSUBMITTED: a submitted form re-renders and legitimately
    // resets, which would make this assertion pass without testing anything.
    await page.selectOption('#main select[name="item_id"]', '2');
    const selectBefore = await page.inputValue('#main select[name="item_id"]');
    check('an option can be chosen and left open', selectBefore === '2', `value ${selectBefore}`);
    await page.waitForTimeout(TICK_MS);
    check('a background tick leaves the main panel standing', await page.locator('#main').count() === 1);
    check('...and the panel is still the Weapons Shop', (await state()).screen === 'weapons');
    check('...and the purchase form survives', await page.locator('#main form[phx-submit="purchase"]').count() === 1);
    check('...and does not reset an open <select>',
        await page.inputValue('#main select[name="item_id"]') === selectBefore,
        `was ${selectBefore}, now ${await page.inputValue('#main select[name="item_id"]')}`);

    // ---- fight until level-up, then until death -----------------------------------------------
    // Entered from the Town form, the way a player does — NOT by typing the URL. Travelling to
    // the Battleground is its own code path, and it crashed the LiveView while a typed URL
    // worked perfectly, so the shortcut this test used to take proved nothing.
    await goHome();
    const battlesBeforeTravel = Number(await page.getAttribute('#screen', 'data-battles'));
    await travel('battle');
    check('travelling to the Battleground from Town fights on arrival',
        Number(await page.getAttribute('#screen', 'data-battles')) > battlesBeforeTravel
        || (await state()).dead,
        `battles ${battlesBeforeTravel} -> ${await page.getAttribute('#screen', 'data-battles')}`);

    // The highest level actually observed, rather than a comparison around one call site:
    // travelling to the Battleground fights on arrival, so a level-up can land inside the heal
    // detour where a narrower check never looks.
    let maxLevel = 1;
    let sawNarrative = false;
    let sawShimmer = false;
    let boughtWeapon = false;
    let boughtArmor = false;
    let current = await state();
    check('the battleground is reachable with a living character', current.screen === 'battle',
        `screen=${current.screen} started=${current.started} dead=${current.dead}`);

    for (let i = 0; i < 120 && !current.dead; i++) {
        // A trip to town: eat, and upgrade whatever the purse now covers. Fighting on with the
        // starting fists never earns enough XP to reach level 2 before an Orc runs out of health,
        // so a player who never shops is not a realistic one. An ambush pins you here regardless.
        // Food comes second until the weapon is bought: an Orc starts 50 adena short of one, and
        // a purse spent on meals never closes that gap — so it fights on with fists, earns too
        // little XP to level, and dies anyway.
        const hungerThreshold = boughtWeapon ? 0.5 : 0.25;
        const wantsFood = current.health < current.maxHealth * hungerThreshold && current.adena >= 7;
        const wantsWeapon = !boughtWeapon && current.adena >= 300;
        const wantsArmor = !boughtArmor && current.adena >= 500;

        if (maxLevel === 1 && !current.ambushed && (wantsFood || wantsWeapon || wantsArmor)) {
            await goHome();

            if (wantsFood) {
                await travel('inn');
                // Eats until healthy or broke. One meal is a losing trade: getting back to the
                // Battleground fights on arrival, which costs more than a cheap dish restores.
                const MEAL_COSTS = [7, 15, 60, 250, 1200];
                for (let meal = 0; meal < 12; meal++) {
                    current = await state();
                    if (current.health >= current.maxHealth * 0.9)
                        break;

                    const best = [...MEAL_COSTS.keys()].reverse().find(i => current.adena >= MEAL_COSTS[i]);
                    if (best === undefined)
                        break;

                    // Eaten while genuinely wounded, so HP really rises — a gain shimmers, damage never does.
                    const shimmer = page.waitForSelector('#sidebar .hp-bar.shimmer-active', { timeout: 2000 })
                        .then(() => true).catch(() => false);

                    if (!(await buy(best)))
                        break;

                    sawShimmer = sawShimmer || await shimmer;
                }

                await leaveShop();
            }

            current = await state();
            maxLevel = Math.max(maxLevel, current.level ?? 1);

            if (!boughtWeapon && current.adena >= 300) {
                await travel('weapons');
                boughtWeapon = await buy(1);
                await leaveShop();
                current = await state();
            }

            if (!boughtArmor && current.adena >= 500) {
                await travel('armors');
                boughtArmor = await buy(1);
                await leaveShop();
            }

            await travel('battle');
            current = await state();
            maxLevel = Math.max(maxLevel, current.level ?? 1);
            continue;
        }

        await fight();
        current = await state();
        maxLevel = Math.max(maxLevel, current.level ?? 1);

        if (!sawNarrative && await page.locator('#main p').count() > 0)
            sawNarrative = true;
    }

    check('fighting narrates the encounter', sawNarrative);
    check('healing while wounded sweeps a shimmer across the HP bar', sawShimmer);
    check('the counters carry their live values for the animation',
        await page.locator('#sidebar [data-value]').count() === 3);
    check('the character levelled up along the way', maxLevel > 1, `reached level ${maxLevel}`);
    check('the character eventually died', current.dead === true);
    check('death pins the player to the death screen', (await state()).screen === 'death');

    // ---- the dead cannot wander ---------------------------------------------------------------
    await page.goto(`${BASE}/inn`, { waitUntil: 'domcontentloaded' });
    check('a dead character is confined to the death screen', (await state()).screen === 'death');

    // ---- submit a highscore, then restart -----------------------------------------------------
    await page.waitForSelector('.phx-connected', { timeout: 8000 });
    check('a legitimate death may write its legacy',
        await page.locator('#main button:has-text("Write your Legacy")').count() === 1);
    await page.click('#main button:has-text("Write your Legacy")');
    await onScreen('highscores');
    const board = await page.textContent('#main table.data-table');
    check('the highscore appears on the board', /BrowserBot/.test(board ?? ''), board?.replace(/\s+/g, ' ').trim().slice(0, 80));
    check('submitting also clears the character', (await state()).started === false);

    await page.click('#main .last a');
    await onScreen('start');
    check('and the board\'s own back link leads to a fresh start', (await state()).screen === 'start');
    check('...with a fresh name field', await page.locator('#main input[name="name"]').count() === 1);

    // ---- the Konami cheat, last: it bars the highscores ---------------------------------------
    await page.fill('#main input[name="name"]', 'Cheater');
    await page.selectOption('#main select[name="race_id"]', '0');
    await page.click('#main button[type="submit"]');
    await onScreen('home');

    // ---- the sidebar reaches the Character screen ---------------------------------------------
    await page.click('#sidebar .stat-row a');
    await onScreen('character');
    check('the sidebar link opens the Character screen', (await state()).screen === 'character');
    check('...headed "Character"',
        (await page.textContent('#main .header-name'))?.trim() === 'Character',
        await page.textContent('#main .header-name'));
    check('...which names the character and its ancestry',
        /Cheater/.test(await page.textContent('#main h2') ?? ''));

    // The cheat is entered here: the screen has no <select> for the arrow keys to walk, and
    // nothing on arrival that could kill the cheater before the sequence lands.
    for (const key of ['ArrowUp', 'ArrowUp', 'ArrowDown', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'ArrowLeft', 'ArrowRight', 'b', 'a'])
        await page.keyboard.press(key);

    await page.waitForSelector('#effects [data-effect-id="konami_cheat"]', { timeout: 8000 })
        .then(() => check('the Konami sequence marks the cheater', true))
        .catch(() => check('the Konami sequence marks the cheater', false));

    // ---- keyboard play -------------------------------------------------------------------------
    // Links are deliberately not focused — Space scrolls a link instead of activating it — so a
    // screen whose only controls are links correctly takes no focus at all.
    check('a screen with no controls does not steal focus',
        await page.evaluate(() => document.activeElement === document.body), 
        await page.evaluate(() => document.activeElement?.tagName));

    await page.click('#main .back a');
    await onScreen('home');
    check('the Character screen\'s back link continues the journey', (await state()).screen === 'home');

    await travel('suicide');
    check('Suicide offers to Return before a choice is made',
        (await actionButton()).label === 'Return', JSON.stringify(await actionButton()));
    await page.selectOption('#main select[name="confirm"]', 'no');
    check('...a change of heart is not styled as danger',
        (await actionButton()).label === 'Phew 😅'
        && (await actionButton()).cls === 'btn btn-secondary', JSON.stringify(await actionButton()));
    await page.selectOption('#main select[name="confirm"]', 'yes');
    check('...but going through with it is',
        (await actionButton()).label === 'Do it 🥀'
        && (await actionButton()).cls === 'btn btn-danger', JSON.stringify(await actionButton()));
    await page.click('#main form[phx-submit="suicide"] button[type="submit"]');
    await onScreen('death');
    check('a cheater who quits is dead', (await state()).dead === true);
    check('...and the death screen is headed "Game Over"',
        (await page.textContent('#main .header-name'))?.trim() === 'Game Over',
        await page.textContent('#main .header-name'));
    check('...and may NOT write a legacy',
        await page.locator('#main button:has-text("Write your Legacy")').count() === 0);
    check('...but the death screen never takes focus',
        await page.evaluate(() => document.activeElement === document.body || document.activeElement?.tagName === 'HTML'));

    check('no request to the app failed', failedRequests.length === 0, failedRequests.join(' | '));
    check('no console errors', consoleErrors.length === 0, consoleErrors.join(' | '));
} catch (err) {
    check(`walkthrough threw: ${err.message}`, false);
} finally {
    await browser.close();
}

console.log(failures.length === 0 ? '\nAll browser checks passed.' : `\n${failures.length} check(s) failed.`);
process.exit(failures.length === 0 ? 0 : 1);
