/**
 * Drives the real game in a real browser. Unit tests and jsdom cannot see CSP enforcement, a
 * stale bundle, or a background push wiping the panel — every browser-only bug in this project
 * lived in exactly that gap.
 *
 * One character, played normally, end to end. What it asserts is what the browser alone can see:
 * screens render, controls answer, focus lands where the keyboard needs it. How a fight rolls
 * belongs to the unit suite, which can seed the dice; nothing here claims a level was reached.
 * Every lineage is covered by races.mjs.
 *
 * Usage: start the isolated server (`e2e/serve.sh`), then
 *   LD_LIBRARY_PATH=~/.local/lib/playwright-deps node e2e/walkthrough.mjs
 */
import { chromium } from 'playwright';
import { BASE, reporter, traceAudio, controls } from './helpers.mjs';

const TICK_MS = 6000; // the regen tick is 5s; allow a margin

const { check, failures } = reporter();
const browser = await chromium.launch();
const context = await browser.newContext();
await traceAudio(context);

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

const {
    state, onScreen, goHome, buttonSettles, buy, leaveShop, travel, fight, boardRows, activeFilter,
} = controls(page);

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
    // `page.goto` on purpose: a TYPED URL is what is under test here, and a visitor has no link to
    // click. Everywhere else this clicks, because a route only ever reached by URL is untested.
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
    let btn = await buttonSettles('Travel');
    check('Town offers to Travel before anything is picked', btn.label === 'Travel', JSON.stringify(btn));
    await page.selectOption('#main select[name="to"]', 'suicide');
    btn = await buttonSettles('⚰️ Perish');
    check('...and turns into Perish when Suicide is chosen', btn.label === '⚰️ Perish', JSON.stringify(btn));
    await page.selectOption('#main select[name="to"]', 'inn');
    btn = await buttonSettles('Travel');
    check('...and back to Travel for anywhere else', btn.label === 'Travel', JSON.stringify(btn));

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

    // The filters themselves are checked after a legacy is written, further down: on a fresh
    // database this board is empty, and "narrows" cannot mean anything about no rows at all.
    check('the board opens on All', (await activeFilter())?.trim() === 'All', await activeFilter());

    await page.click('#main .last a');
    await onScreen('home');

    await travel('inn');
    check('the Inn is headed "Inn"',
        (await page.textContent('#main .header-name'))?.trim() === 'Inn',
        await page.textContent('#main .header-name'));
    let shopBtn = await buttonSettles('Return');
    check('a shop offers to Return until something is picked',
        shopBtn.label === 'Return' && shopBtn.cls === 'btn btn-secondary', JSON.stringify(shopBtn));
    check('the Inn hands focus to its own picker, not a hidden field',
        await page.evaluate(() => document.activeElement?.getAttribute('name')) === 'item_id',
        await page.evaluate(() => document.activeElement?.tagName + '/' + (document.activeElement?.getAttribute('name') ?? '')));
    const beforeMeal = await state();
    await page.selectOption('#main select[name="item_id"]', '0'); // Spiced Ale, 7 adena
    shopBtn = await buttonSettles('🪙 Order');
    check('...and to Order once a dish is chosen',
        shopBtn.label === '🪙 Order' && shopBtn.cls === 'btn', JSON.stringify(shopBtn));
    await page.click('#main form[phx-submit="purchase"] button[type="submit"]');
    await page.waitForSelector('#main .alert', { timeout: 8000 });
    // Scoped to #main: the sidebar's panels carry .panel-body too.
    const mealText = await page.textContent('#main .alert');
    check('ordering a meal reports back', /You have bought/.test(mealText), mealText?.trim().slice(0, 60));
    check('...and the purse reflects the spend', (await state()).adena === beforeMeal.adena - 7);
    // LiveView restores focus to the button that submitted, which left a keyboard player on Order
    // with the picker they buy from next unreachable without reaching for the mouse.
    check('...and buying hands focus back to the picker, not the button just pressed',
        await page.evaluate(() => document.activeElement?.getAttribute('name')) === 'item_id',
        await page.evaluate(() => document.activeElement?.tagName + '/' + (document.activeElement?.getAttribute('name') ?? '')));

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

    // ---- the battleground ---------------------------------------------------------------------
    // From the Town form, not a typed URL: travelling is its own path, and it once crashed the
    // LiveView while the URL worked perfectly.
    await goHome();
    const battlesBeforeTravel = Number(await page.getAttribute('#screen', 'data-battles'));
    await travel('battle');
    check('travelling to the Battleground from Town fights on arrival',
        Number(await page.getAttribute('#screen', 'data-battles')) > battlesBeforeTravel
        || (await state()).dead,
        `battles ${battlesBeforeTravel} -> ${await page.getAttribute('#screen', 'data-battles')}`);

    // Focus that cannot be seen is not an affordance. Arriving by mouse leaves the button focused
    // but not :focus-visible, so the ring has to come from plain :focus — as it does on a select.
    // Named by colour, not merely "differs from idle": the base drop shadow alone would pass that.
    const RING = '201, 168, 76';
    const armedRing = () => page.evaluate(() => {
        const el = document.activeElement;
        return el?.matches('#main .btn')
            ? getComputedStyle(el).boxShadow
            : `focus is on ${el?.tagName ?? 'nothing'}, not a button`;
    });
    // Waits: the ring transitions in, so reading straight after arrival catches a mid-flight value.
    await page.waitForFunction(
        ring => document.activeElement?.matches('#main .btn')
            && getComputedStyle(document.activeElement).boxShadow.includes(ring),
        RING, { timeout: 3000 }).catch(() => {});
    check('...and the button it arms is visibly focused, not merely focused',
        (await armedRing()).includes(RING), await armedRing());

    let fightsFought = 0;
    let focusLeftTheFight = false;
    let current = await state();
    check('the battleground is reachable with a living character', current.screen === 'battle',
        `screen=${current.screen} started=${current.started} dead=${current.dead}`);

    // ---- a gain shimmers, and damage never does -------------------------------------------------
    // Driven, not waited for. Arriving already fought once, and an Orc regenerates nothing, so it
    // stays hurt until it eats — which makes the heal, and the sweep it triggers, something this
    // run causes rather than something it hopes the dice allow.
    while (fightsFought < 3 && !current.dead && current.health === current.maxHealth) {
        await fight();
        fightsFought++;
        current = await state();
    }

    check('fighting wounds the character', current.health < current.maxHealth,
        `${current.health}/${current.maxHealth} after arrival and ${fightsFought} further fight(s)`);
    check('...and narrates the encounter', await page.locator('#main p').count() > 0);
    // Never fires in practice — three fights cannot spend an Orc's opening health — but it says so
    // outright rather than skipping the shimmer in silence if it ever does.
    check('...and leaves it alive to reach the Inn', !current.dead, `died after ${fightsFought}`);

    if (!current.dead) {
        await goHome();
        await travel('inn');
        const wounded = await state();
        // Armed before the purchase: the sweep lasts 600ms and is gone by the time adena settles.
        const shimmer = page.waitForSelector('#sidebar .hp-bar.shimmer-active', { timeout: 3000 })
            .then(() => true).catch(() => false);
        const bought = await buy(0); // Spiced Ale, 7 adena — inside every lineage's opening purse
        const healed = await state();

        check('a meal heals the wounded', bought && healed.health > wounded.health,
            `${wounded.health} -> ${healed.health}`);
        check('...and the gain sweeps a shimmer across the HP bar', await shimmer);
        await leaveShop();
        await travel('battle');
        current = await state();
    }

    // ---- the road ends at the grave -------------------------------------------------------------
    // Fights on without shopping, so health only falls and this terminates. Nothing is claimed
    // about the level reached or the damage taken: the dice own that, and balance_golden_test.exs
    // is where they can be held still.
    for (let i = 0; i < 200 && !current.dead && current.screen === 'battle'; i++) {
        await fight();
        fightsFought++;
        current = await state();
        // The battlefield is played by hammering one button, so it has to still be under the
        // keyboard afterwards — including across an ambush, which swaps it for a different button.
        if (!current.dead && !focusLeftTheFight)
            focusLeftTheFight = await page.evaluate(
                () => document.activeElement?.getAttribute('phx-click') !== 'fight');
    }

    check('the counters carry their live values for the animation',
        await page.locator('#sidebar [data-value]').count() === 3);
    check('the road ends at the grave', current.dead === true,
        `dead=${current.dead} after ${fightsFought} fights (cap 200)`);
    check('death pins the player to the death screen', (await state()).screen === 'death');
    check('the Fight button stays under the keyboard between fights', !focusLeftTheFight,
        `${fightsFought} fights`);
    // Dying in battle morphs the Fight button into "Write your Legacy!" in place, so focus rides
    // across with it — and the Space that fought submits a score nobody has read yet.
    check('...but dying releases it, so no stray Space writes a legacy',
        await page.evaluate(() => !document.querySelector('#screen')?.contains(document.activeElement)),
        await page.evaluate(() => document.activeElement?.tagName + '/' + (document.activeElement?.textContent?.trim().slice(0, 20) ?? '')));

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

    // Here, not on arrival: BrowserBot's Orc entry is what makes the board non-empty and the Elf
    // filter narrower than All. Submitting lands on /highscores/<own race>, so widen first — and
    // each wait names the path it expects, since "not /highscores" was already true.
    await page.click('#main .action-links a:has-text("All")');
    await page.waitForFunction(() => location.pathname === '/highscores', null, { timeout: 5000 });
    const allRows = await boardRows();
    check('the board has the entry just written', allRows > 0, `${allRows} rows`);

    await page.click('#main .action-links a:has-text("Elf") >> nth=0');
    await page.waitForFunction(() => location.pathname === '/highscores/elf', null, { timeout: 5000 });
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
    let endBtn = await buttonSettles('Return');
    check('Suicide offers to Return before a choice is made', endBtn.label === 'Return', JSON.stringify(endBtn));
    await page.selectOption('#main select[name="confirm"]', 'no');
    endBtn = await buttonSettles('Phew 😅');
    check('...a change of heart is not styled as danger',
        endBtn.label === 'Phew 😅' && endBtn.cls === 'btn btn-secondary', JSON.stringify(endBtn));
    await page.selectOption('#main select[name="confirm"]', 'yes');
    endBtn = await buttonSettles('Do it 🥀');
    check('...but going through with it is',
        endBtn.label === 'Do it 🥀' && endBtn.cls === 'btn btn-danger', JSON.stringify(endBtn));
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
