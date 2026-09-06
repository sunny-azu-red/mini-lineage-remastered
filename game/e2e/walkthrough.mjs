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

/** Travels via the Town form, which is how a player actually moves. */
async function travel(to) {
    await onScreen('home');
    await page.selectOption('#main select[name="to"]', to);
    await page.click('#main form[phx-submit="navigate"] button[type="submit"]');
    await onScreen(to);
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

    const before404 = consoleErrors.length;
    const notFound = await page.goto(`${BASE}/no-such-road`, { waitUntil: 'domcontentloaded' });
    check('an unknown URL returns 404, not a crash', notFound?.status() === 404, String(notFound?.status()));
    check('...wearing the game shell rather than bare text',
        await page.locator('#main .panel-body').count() === 1);
    check('...and in a dev build it says what happened',
        await page.locator('#main .code-block').count() === 1);
    // Asking for a 404 legitimately logs one console error. Drop exactly those, nothing else.
    consoleErrors.push(...consoleErrors.splice(before404).filter(e => !/404/.test(e)));

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

    // ---- the effect timer counts down locally --------------------------------------------------
    const timerText = () => page.textContent('#effects [data-effect-id="newbie_blessing"] .effect-timer');
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
    await page.goto(BASE, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('.phx-connected', { timeout: 8000 });
    await travel('inn');
    const beforeMeal = await state();
    await page.selectOption('#main select[name="item_id"]', '0'); // Spiced Ale, 7 adena
    await page.click('#main form[phx-submit="purchase"] button[type="submit"]');
    await page.waitForSelector('#main .alert', { timeout: 8000 });
    // Scoped to #main: the sidebar's panels carry .panel-body too.
    const mealText = await page.textContent('#main .alert');
    check('ordering a meal reports back', /You have bought/.test(mealText), mealText?.trim().slice(0, 60));
    check('...and the purse reflects the spend', (await state()).adena === beforeMeal.adena - 7);

    await tab.waitForFunction(
        (expected) => document.querySelector('#screen')?.dataset.adena === expected,
        String(beforeMeal.adena - 7),
        { timeout: 8000 },
    ).then(() => check('the other tab sees the spend without acting', true))
     .catch(async () => check('the other tab sees the spend without acting', false,
        `tab adena ${await tab.getAttribute('#screen', 'data-adena')}`));
    await tab.close();

    await page.goto(BASE, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('.phx-connected', { timeout: 8000 });
    await travel('weapons');
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
    await page.goto(`${BASE}/battle`, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('.phx-connected', { timeout: 8000 });

    let sawLevelUp = false;
    let sawNarrative = false;
    let sawShimmer = false;
    let current = await state();
    check('the battleground is reachable with a living character', current.screen === 'battle',
        `screen=${current.screen} started=${current.started} dead=${current.dead}`);

    for (let i = 0; i < 120 && !current.dead; i++) {
        // Heal at the Inn while we can still afford it and are not pinned by an ambush.
        if (!sawLevelUp && !current.ambushed && current.health < current.maxHealth * 0.45 && current.adena >= 7) {
            await page.goto(`${BASE}/inn`, { waitUntil: 'domcontentloaded' });
            await page.waitForSelector('.phx-connected', { timeout: 8000 });
            await page.selectOption('#main select[name="item_id"]', '0');
            // Eaten while genuinely wounded, so HP really rises — a gain shimmers, damage never does.
            const shimmer = page.waitForSelector('#sidebar .hp-bar.shimmer-active', { timeout: 3000 })
                .then(() => true).catch(() => false);
            await page.click('#main form[phx-submit="purchase"] button[type="submit"]');
            await page.waitForSelector('#main .alert', { timeout: 8000 });
            sawShimmer = sawShimmer || await shimmer;
            await page.goto(`${BASE}/battle`, { waitUntil: 'domcontentloaded' });
            await page.waitForSelector('.phx-connected', { timeout: 8000 });
            current = await state();
            continue;
        }

        const levelBefore = current.level;
        await fight();
        current = await state();

        if (!sawNarrative && await page.locator('#main p').count() > 0)
            sawNarrative = true;
        if (current.level !== null && levelBefore !== null && current.level > levelBefore)
            sawLevelUp = true;
    }

    check('fighting narrates the encounter', sawNarrative);
    check('healing while wounded sweeps a shimmer across the HP bar', sawShimmer);
    check('the counters carry their live values for the animation',
        await page.locator('#sidebar [data-value]').count() === 3);
    check('the character levelled up along the way', sawLevelUp, `reached level ${current.level}`);
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

    await page.goto(BASE, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('.phx-connected', { timeout: 8000 });
    check('and the game is ready to start again', (await state()).screen === 'start');
    check('...with a fresh name field', await page.locator('#main input[name="name"]').count() === 1);

    // ---- the Konami cheat, last: it bars the highscores ---------------------------------------
    await page.fill('#main input[name="name"]', 'Cheater');
    await page.selectOption('#main select[name="race_id"]', '0');
    await page.click('#main button[type="submit"]');
    await onScreen('home');

    // Done from the Battleground, whose first control is a button — on Town the arrow keys would
    // also be walking the travel <select>.
    await page.goto(`${BASE}/battle`, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('.phx-connected', { timeout: 8000 });
    for (const key of ['ArrowUp', 'ArrowUp', 'ArrowDown', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'ArrowLeft', 'ArrowRight', 'b', 'a'])
        await page.keyboard.press(key);

    await page.waitForSelector('#effects [data-effect-id="konami_cheat"]', { timeout: 8000 })
        .then(() => check('the Konami sequence marks the cheater', true))
        .catch(() => check('the Konami sequence marks the cheater', false));

    // ---- keyboard play -------------------------------------------------------------------------
    const focused = await page.evaluate(() => document.activeElement?.tagName);
    check('the panel takes focus so the game plays from the keyboard',
        ['BUTTON', 'INPUT', 'SELECT', 'A'].includes(focused), `focus on ${focused}`);

    await page.goto(`${BASE}/suicide`, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('.phx-connected', { timeout: 8000 });
    await page.selectOption('#main select[name="confirm"]', 'yes');
    await page.click('#main form[phx-submit="suicide"] button[type="submit"]');
    await onScreen('death');
    check('a cheater who quits is dead', (await state()).dead === true);
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
