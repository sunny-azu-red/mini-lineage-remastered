/**
 * One character, made and stood in its village, end to end: `mix e2e walkthrough`. It asserts only
 * what the browser alone can see; every starting set is races.mjs's.
 */
import { readFileSync } from 'node:fs';
import { chromium } from 'playwright';
import { BASE, reporter, controls } from './helpers.mjs';

const { check, failures } = reporter();
const browser = await chromium.launch();
const context = await browser.newContext();
const page = await context.newPage();

const consoleErrors = [];
const failedRequests = [];
page.on('console', m => { if (m.type() === 'error') consoleErrors.push(m.text()); });
page.on('pageerror', e => consoleErrors.push(`pageerror: ${e.message}`));
page.on('requestfailed', r => {
    // Google Fonts may be unreachable offline; that is not the app's fault. Nor is a request the
    // browser cancelled on navigating away, which a socket fallen back to long-polling always has.
    if (r.url().startsWith(BASE) && r.failure()?.errorText !== 'net::ERR_ABORTED')
        failedRequests.push(`${r.method()} ${r.url()} :: ${r.failure()?.errorText}`);
});

const { state, onScreen, create, text } = controls(page);

try {
    // Never `networkidle`: the LiveView websocket stays open, so it never settles.
    await page.goto(BASE, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('.phx-connected', { timeout: 8000 });

    // ---- the stylesheet actually applied, not merely 200'd -----------------------------------
    const bg = await page.locator('body').evaluate(el => getComputedStyle(el).backgroundColor);
    const font = await page.locator('.header-title').evaluate(el => getComputedStyle(el).fontFamily);
    check('the stylesheet is applied', bg !== 'rgba(0, 0, 0, 0)', `body background ${bg}`);
    check('...including the display font', /Cinzel/i.test(font), font);
    check('LiveView connects through the CSP', true);

    // This server is the e2e one: a footer reading "development" means the run is driving the dev
    // server on 4000, against real data.
    const footer = await page.textContent('#copyright');
    check('the footer names this as the testing build', /testing/.test(footer ?? ''), footer?.trim());
    check('...and flags it as a debug build, in the colour that build wears',
        await page.locator('#copyright .build-testing').count() === 1);

    // ---- the two short-form formatters agree ------------------------------------------------
    // The count-up formats its own frames in hooks/animated-values.js, so both sides of
    // Format.short read one table; Elixir reads it in format_test.exs.
    const { cases } = JSON.parse(readFileSync('test/fixtures/short_format.json', 'utf8'));
    const mismatched = await page.evaluate(
        (rows) => rows
            .filter(([value, expected]) => window.__shortFigure(value) !== expected)
            .map(([value, expected]) => `${value}: ${window.__shortFigure(value)} != ${expected}`),
        cases,
    );
    check('the browser shortens a figure exactly as the server does', mismatched.length === 0,
        mismatched.join(' | '));

    const cookie = (await context.cookies()).find(c => c.name === '_mini_lineage_key');
    check('the session cookie is httpOnly', cookie?.httpOnly === true);
    check('...and sameSite Lax', cookie?.sameSite === 'Lax', String(cookie?.sameSite));

    // ---- what the game does not have says so --------------------------------------------------
    // Fetched, not navigated: a 404 in the address bar writes a console error, and this suite
    // asserts there are none. The Battleground went to legacy/, and its address with it.
    const gone = await page.request.get(`${BASE}/battle`);
    check('an address the game used to own now says it does not', gone.status() === 404,
        String(gone.status()));
    check('...in the game\'s own shell, not a bare server page',
        (await gone.text()).includes('That road leads nowhere'));

    const unknown = await page.request.get(`${BASE}/no-such-road`);
    check('an unknown URL says so rather than moving the reader', unknown.status() === 404,
        String(unknown.status()));
    check('...and leaves the address alone, so a typo is visible',
        new URL(unknown.url()).pathname === '/no-such-road', unknown.url());

    // Served the game instead, a mistyped stylesheet would come back as HTML and render unstyled.
    const asset = await page.request.get(`${BASE}/assets/css/not-a-file.css`);
    check('...and a missing asset does too, rather than answering with a page', asset.status() === 404,
        String(asset.status()));

    // ---- the error screen is a real, styled screen ---------------------------------------------
    await page.goto(`${BASE}/error`, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('.phx-connected', { timeout: 8000 });
    check('the error screen is routable and styled', (await state()).screen === 'error');
    check('...and offers a way out',
        await page.locator('#main a:has-text("Return to safer lands")').count() === 1);

    // ---- a visitor reads the lineages, and is sent back to choose one -------------------------
    await page.goto(BASE, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('.phx-connected', { timeout: 8000 });
    await page.click('#main a:has-text("Chronicles of Ancestry")');
    await onScreen('races');
    check('Chronicles of Ancestry is public', (await state()).screen === 'races');
    check('...and its way back is to game start', (await text('#main .back')).includes('game start'),
        await text('#main .back'));
    await page.click('#main .back a');
    await onScreen('start');

    // ---- create a character -------------------------------------------------------------------
    // Deliberately BEFORE the socket connects: the dead render is interactive, and the first live
    // render must not reset a choice made in that window.
    await page.goto(BASE, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('#main select[name="race_id"]', { timeout: 8000 });
    await page.fill('#main input[name="name"]', 'BrowserBot');
    await page.selectOption('#main select[name="race_id"]', '1');
    await page.selectOption('#main select[name="path"]', 'mystic');

    await page.waitForSelector('.phx-connected', { timeout: 8000 });
    const chosen = [
        await page.inputValue('#main input[name="name"]'),
        await page.inputValue('#main select[name="race_id"]'),
        await page.inputValue('#main select[name="path"]'),
    ].join(' / ');
    check('a choice made before the socket connects survives the first live render',
        chosen === 'BrowserBot / 1 / mystic', chosen);
    check('the start screen hands focus to the name, so it plays from the keyboard',
        await page.evaluate(() => document.activeElement?.getAttribute('name')) === 'name',
        await page.evaluate(() => document.activeElement?.outerHTML.slice(0, 60)));

    await page.click('#main button[type="submit"]');
    await onScreen('home');

    const born = await state();
    check('creating a character lands in its own village', born.screen === 'home');
    check('...headed with its name', (await text('#main .header-name')) === 'Orc Village',
        await text('#main .header-name'));
    check('...and the document title names it', await page.title() === 'Mini Lineage - Orc Village',
        await page.title());
    check('...and the City of Aden is nowhere on the page', !(await text('body')).includes('City of Aden'));
    check('...with the welcome that sent it out from there',
        /You chose the 🧟 Orc Mystic, .* set out from 🏕️ Orc Village/.test(await text('#main .alert')),
        await text('#main .alert'));
    // A flash heads the panel without being its content, so the heading under it sits as the first.
    const gap = await page.evaluate(() =>
        document.querySelector('#main h2').getBoundingClientRect().top
        - document.querySelector('#flash').getBoundingClientRect().bottom);
    check('...and its heading sits under the flash as if it came first, 12px below it', gap === 12, `${gap}px`);
    check('the sidebar appears alongside it', await page.locator('#sidebar').count() === 1);
    check('...at level 1, with full bars', born.level === 1 && born.health === born.maxHealth
        && born.mp === born.maxMp, JSON.stringify(born));
    check('...no experience yet, and 68 to the next level, as rules §12 has it',
        born.xp === 0 && born.xpRequired === 68, `${born.xp}/${born.xpRequired}`);
    check('...and its Stats beside them', await page.locator('#stats [data-key="p-atk"]').count() === 1
        && /^\d+\.\d%$/.test(await text('#stat-critical')), await text('#stat-critical'));
    check('...and an empty purse', born.adena === 0, String(born.adena));
    check('...resting, as a character with nothing to fight always is',
        await page.locator('#effects [data-effect-id="resting"]').count() === 1);

    // ---- a flash belongs to its arrival, and to nothing after it -----------------------------
    await page.click('#header-link');
    await page.waitForSelector('#main .alert', { state: 'detached', timeout: 5000 }).catch(() => {});
    check('a flash does not survive coming back to the same screen',
        await page.locator('#main .alert').count() === 0);

    // ---- a character may read, and is brought home ---------------------------------------------
    await page.goto(`${BASE}/races`, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('.phx-connected', { timeout: 8000 });
    check('a character may read the Chronicles of Ancestry', (await state()).screen === 'races');
    check('...whose way back continues the journey',
        (await text('#main .back')).includes('Continue your journey'));
    await page.click('#main .back a');
    await onScreen('home');
    check('...and leads home', (await text('#main .header-name')) === 'Orc Village');

    // ---- a second tab follows along -------------------------------------------------------------
    const tab = await context.newPage();
    await tab.goto(BASE, { waitUntil: 'domcontentloaded' });
    await tab.waitForSelector('.phx-connected', { timeout: 8000 });
    check('a second tab sees the same character',
        await tab.getAttribute('#sidebar [data-key="hp"]', 'data-value') === String(born.health));
    await tab.close();

    // ---- Stats folds at any width, opens folded, and stays as the reader left it -------------
    const stats = page.locator('#stats .panel-body');
    const statsHidden = () => stats.waitFor({ state: 'hidden', timeout: 3000 }).then(() => true, () => false);
    check('beside the main panel Stats opens folded', await statsHidden());
    await page.click('#stats .panel-toggle');
    check('...until its header opens it', await stats.isVisible());
    await page.reload({ waitUntil: 'domcontentloaded' });
    await page.waitForSelector('.phx-connected', { timeout: 8000 });
    check('...and a refresh keeps it open, the panel being the reader\'s own', await stats.isVisible());
    await page.click('#stats .panel-toggle');
    check('...until it is folded again', await statsHidden());

    // ---- the Inventory folds on a phone, and stays as the reader left it -----------------------
    const inventory = page.locator('#inventory .panel-body');
    const folded = () => inventory.waitFor({ state: 'hidden', timeout: 3000 }).then(() => true, () => false);
    check('beside the main panel the Inventory has no fold to offer',
        await page.locator('#inventory .panel-toggle').isDisabled() && await inventory.isVisible());
    const desktop = page.viewportSize();
    await page.setViewportSize({ width: 320, height: 800 });
    // The hook hears of the new width from a resize event, which lands after the call returns.
    const offered = await page.waitForFunction(
        () => !document.querySelector('#inventory .panel-toggle').disabled, null, { timeout: 3000 })
        .then(() => true, () => false);
    check('...stacked on a phone it folds, and opens unfolded', offered && await inventory.isVisible());
    await page.click('#inventory .panel-toggle');
    check('...until its header folds it', await folded());
    await page.reload({ waitUntil: 'domcontentloaded' });
    await page.waitForSelector('.phx-connected', { timeout: 8000 });
    check('...and a refresh keeps the fold, the panel being the reader\'s own', await folded());
    await page.click('#inventory .panel-toggle');
    check('...until they open it again', await inventory.isVisible());
    await page.setViewportSize(desktop);

    // ---- a returning browser is the same character -----------------------------------------------
    await page.goto(BASE, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('.phx-connected', { timeout: 8000 });
    check('a returning browser comes back to its village, not to game start',
        (await state()).screen === 'home' && (await text('#sidebar .header-name')) === 'BrowserBot',
        await text('#sidebar .header-name'));

    // ---- the temporary Quit, for trying every set from one browser --------------------------
    await page.click('#quit');
    await onScreen('start');
    check('Quit goes back to game start, with no character', (await state()).started === false);
    await create('AgainBot', 3, 'fighter');
    check('...and the same browser starts another at once',
        (await text('#main .header-name')) === 'Dark Elven Village', await text('#main .header-name'));

    check('no request to the app failed', failedRequests.length === 0, failedRequests.join(' | '));
    check('no console errors', consoleErrors.length === 0, consoleErrors.join(' | '));
} catch (err) {
    check(`walkthrough threw: ${err.message}`, false);
} finally {
    await browser.close();
}

console.log(failures.length === 0 ? '\nAll checks passed.' : `\n${failures.length} check(s) failed.`);
process.exit(failures.length === 0 ? 0 : 1);
