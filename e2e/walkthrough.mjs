/**
 * One character, made and stood in its village, end to end: `mix e2e walkthrough`. It asserts only
 * what the browser alone can see; every starting set is races.mjs's.
 */
import { readFileSync } from 'node:fs';
import { chromium } from 'playwright';
import { BASE, reporter, traceAudio, controls, marginsLeftAtEnds } from './helpers.mjs';

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
    // Google Fonts may be unreachable offline; that is not the app's fault. Nor is a request the
    // browser cancelled on navigating away, which a socket fallen back to long-polling always has.
    if (r.url().startsWith(BASE) && r.failure()?.errorText !== 'net::ERR_ABORTED')
        failedRequests.push(`${r.method()} ${r.url()} :: ${r.failure()?.errorText}`);
});

const { state, onScreen, create, text, adena } = controls(page);

try {
    // Never `networkidle`: the LiveView websocket stays open, so it never settles.
    await page.goto(BASE, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('.phx-connected', { timeout: 8000 });

    // ---- the stylesheet actually applied, not merely 200'd -----------------------------------
    const bg = await page.locator('body').evaluate(el => getComputedStyle(el).backgroundColor);
    const font = await page.locator('.header-title').evaluate(el => getComputedStyle(el).fontFamily);
    check('the stylesheet is applied', bg !== 'rgba(0, 0, 0, 0)', `body background ${bg}`);
    check('...including the display font', /Cinzel/i.test(font), font);
    check('the game\'s name is the page\'s one h1',
        await page.locator('h1').count() === 1 && (await text('#header h1')) === 'Mini Lineage', await text('h1'));
    // The connect itself is the wait above; what can still go wrong is the CSP refusing something.
    const refused = consoleErrors.filter(e => /Content Security Policy/i.test(e));
    check('LiveView connects through the CSP, which refuses nothing', refused.length === 0, refused.join(' | '));

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
    const percents = JSON.parse(readFileSync('test/fixtures/percent_format.json', 'utf8')).cases;
    const offPercent = await page.evaluate(
        (rows) => rows
            .filter(([value, expected]) => window.__percentFigure(value) !== expected)
            .map(([value, expected]) => `${value}: ${window.__percentFigure(value)} != ${expected}`),
        percents,
    );
    check('...and writes a percentage exactly as the server does', offPercent.length === 0, offPercent.join(' | '));

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
    check('...with no way back of its own, the banner being the way home',
        await page.locator('#main a').count() === 0 && await page.getAttribute('#header-link', 'href') === '/');

    // ---- a visitor reads the lineages, and is sent back to choose one -------------------------
    await page.goto(BASE, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('.phx-connected', { timeout: 8000 });
    check('game start is headed with its call to begin',
        (await text('#main h2.header-name')) === '🐣 A New Bloodline Rises', await text('#main h2.header-name'));
    check('...and no second heading saying it again', await page.locator('#screen h2').count() === 1);
    await page.click('#main a:has-text("Chronicles of Ancestry")');
    await onScreen('races');
    check('Chronicles of Ancestry is public', (await state()).screen === 'races');
    await page.click('#header-link');
    await onScreen('start');
    check('...and the banner takes a visitor back to game start', (await state()).screen === 'start');

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
    await onScreen('town');

    const born = await state();
    const fanfare = await page.evaluate(() => window.__notes.splice(0));
    check('creating a character plays the new-game fanfare, three triangles and a square',
        fanfare.join(',') === 'triangle,triangle,triangle,square', fanfare.join(','));
    check('creating a character lands in its own village', born.screen === 'town');
    check('...at the village\'s own address', new URL(page.url()).pathname === '/orc-village', page.url());
    check('...headed with its name', (await text('#main .header-name')) === '🏕️ Orc Village',
        await text('#main .header-name'));
    check('...and the document title names it', await page.title() === 'Mini Lineage - Orc Village',
        await page.title());
    check('...and no second heading saying it again', await page.locator('#screen h2').count() === 1);
    const untitled = await page.$$eval('.panel', panels =>
        panels.filter(panel => !panel.querySelector(':scope > h2, :scope > .panel-header > h2')).length);
    check('...and every panel on it, the sidebar\'s too, is titled with an h2, under the one h1',
        untitled === 0 && await page.locator('h1').count() === 1, `${untitled} untitled`);
    check('...and the City of Aden is nowhere on the page', !(await text('body')).includes('City of Aden'));
    check('...with the welcome that sent it out from there',
        /You chose the 🧟 Orc Mystic, .* set out from 🏕️ Orc Village/.test(await text('#main .alert')),
        await text('#main .alert'));
    // A flash heads the panel without being its content, so what opens the screen sits as the first.
    const gap = await page.evaluate(() =>
        document.querySelector('#flash + *').getBoundingClientRect().top
        - document.querySelector('#flash').getBoundingClientRect().bottom);
    check('...and its description sits under the flash as if it came first, 12px below it', gap === 12, `${gap}px`);
    check('...and nothing destructive takes the keyboard on arrival',
        await page.evaluate(() => document.activeElement?.value) === 'gatekeeper',
        await page.evaluate(() => document.activeElement?.outerHTML.slice(0, 60)));
    check('the sidebar appears alongside it', await page.locator('#sidebar').count() === 1);
    check('...headed with the race and class, the level beside the name under it',
        (await text('#sidebar .header-name')) === '🧟 Orc Mystic'
        && (await text('#sidebar .level-badge')) === '1' && (await text('#character-name')) === 'BrowserBot',
        `${await text('#sidebar .header-name')} / ${await text('#sidebar .level-badge')} ${await text('#character-name')}`);
    check('...at level 1, with full bars', born.level === 1 && born.health === born.maxHealth
        && born.mp === born.maxMp, JSON.stringify(born));
    check('...no experience yet, and 68 to the next level, as rules §12 has it',
        born.xp === 0 && born.xpRequired === 68, `${born.xp}/${born.xpRequired}`);
    const labels = await page.locator('#sidebar .bar-label').allTextContents();
    check('...each bar naming itself inside it, and XP as a share of the level',
        labels.join(',') === 'HP,MP,XP' && (await text('#xp-bar ~ .bar-text')) === '0.00%',
        `${labels} / ${await text('#xp-bar ~ .bar-text')}`);
    check('...and an empty purse', born.adena === 0, String(born.adena));
    check('...resting, as a character with nothing to fight always is',
        await page.locator('#effects [data-effect-id="resting"]').count() === 1);

    // ---- a flash belongs to its arrival, and to nothing after it -----------------------------
    await page.click('#header-link');
    await page.waitForSelector('#main .alert', { state: 'detached', timeout: 5000 }).catch(() => {});
    check('a flash does not survive coming back to the same screen',
        await page.locator('#main .alert').count() === 0);

    // ---- muting is the browser's, and the toggle says so in its own chime --------------------
    await page.click('#sound-toggle');
    check('muting flips the toggle', await page.textContent('#sound-toggle') === '🔇');
    check('...and plays nothing', (await page.evaluate(() => window.__notes.splice(0))).length === 0);
    await page.reload({ waitUntil: 'domcontentloaded' });
    await page.waitForSelector('.phx-connected', { timeout: 8000 });
    check('...and a refresh keeps it muted', await page.textContent('#sound-toggle') === '🔇');
    await page.click('#sound-toggle');
    check('unmuting flips it back', await page.textContent('#sound-toggle') === '🔊');
    const chime = await page.evaluate(() => window.__notes.splice(0));
    check('...with a chime of its own, two sines', chime.join(',') === 'sine,sine', chime.join(','));

    // ---- a character may read, and is brought home ---------------------------------------------
    await page.goto(`${BASE}/races`, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('.phx-connected', { timeout: 8000 });
    check('a character may read the Chronicles of Ancestry', (await state()).screen === 'races');
    await page.click('#header-link');
    await onScreen('town');
    check('...and the banner leads home', (await text('#main .header-name')) === '🏕️ Orc Village');
    check('...at its address, not at the root', new URL(page.url()).pathname === '/orc-village', page.url());

    // ---- the name in the sidebar opens the character's own page ------------------------------
    await page.click('#character-name a');
    await onScreen('character');
    check('the sidebar\'s name leads to the character page, at /character',
        new URL(page.url()).pathname === '/character', page.url());
    const sections = await page.$$eval('#screen > .panel h2.header-name', hs => hs.map(h => h.textContent.trim()));
    check('...in a panel for each section, the first naming its ancestry, with no sidebar beside them',
        sections.join('|') === '🧟 BrowserBot of Orc Ancestry|✨ Buffs & Debuffs|⚖️ Combat Stats'
        && await page.locator('#sidebar').count() === 0, sections.join('|'));
    check('...under the game\'s name, the page\'s one h1',
        await page.locator('h1').count() === 1 && (await text('h1')) === 'Mini Lineage', await text('h1'));
    check('...then its class, what it was born with and its race\'s perk in one paragraph, then its level, bars and purse',
        await page.evaluate(() => [...document.querySelectorAll('#screen > .panel')][0]
            .querySelectorAll('.panel-body p').length === 2
            && [...document.querySelectorAll('#character-lineage > p')].map(p => p.id).join(',')
            === 'character-class,character-vitality')
        && (await text('#character-class')).startsWith('You are an Orc Mystic of ')
        && (await text('#character-class')).includes('. Orcs shrug off sleep, root and poison'),
        await text('#character-class'));
    const attributes = await page.$$eval('#character-class .attribute',
        spans => spans.map(s => `${s.firstElementChild.dataset.key} ${s.lastChild.textContent.trim()}`).join(','));
    check('...each attribute its figure, then its name in full',
        attributes === 'char-str Strength,char-con Constitution,char-dex Dexterity,'
        + 'char-int Intelligence,char-wit Wit,char-men Mental Strength', attributes);
    const margins = await marginsLeftAtEnds(page);
    check('...and nothing that ends one, its rows\' sentences included, keeps a margin under it',
        margins.length === 0, margins.join(' | '));
    check('...what is on it, and what each does',
        (await text('#effect-resting')).startsWith('💤 Resting • With nothing yet to fight'),
        await text('#effect-resting'));
    check('...one row each, as the sidebar draws its own',
        await page.locator('.panel-body.rows > .stat-row[id^="effect-"]').count()
        === await page.locator('[id^="effect-"]').count());
    check('...and its figures, as the server wrote them',
        await page.getAttribute('#character-lineage [data-key="char-level"]', 'data-value') === '1'
        && await page.getAttribute('#character-lineage [data-key="char-xp-needed"]', 'data-value') === '68');
    await page.click('#header-link');
    await onScreen('town');
    check('...and the banner leads back to the town', new URL(page.url()).pathname === '/orc-village', page.url());

    // ---- a second tab follows along -------------------------------------------------------------
    const tab = await context.newPage();
    await tab.goto(BASE, { waitUntil: 'domcontentloaded' });
    await tab.waitForSelector('.phx-connected', { timeout: 8000 });
    check('a second tab sees the same character',
        await tab.getAttribute('#sidebar [data-key="hp"]', 'data-value') === String(born.health));
    await tab.close();

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
        (await state()).screen === 'town' && (await text('#character-name')) === 'BrowserBot',
        await text('#character-name'));

    // ---- the Gatekeeper, rules §14 ------------------------------------------------------------
    const teleport = async (to) => {
        await page.selectOption('#teleport-form select', to);
        await page.click('#teleport-form button');
    };
    // Typed with nothing focused, as a player would: a focused <select> takes letters as a search.
    const typeAdena = async () => {
        await page.evaluate(() => document.activeElement?.blur());
        await page.keyboard.type('adena');
    };
    await page.selectOption('#travel-form select', 'gatekeeper');
    await page.click('#travel-form button');
    await onScreen('gatekeeper');
    check('the town\'s way out leads to its Gatekeeper, at an address of its own',
        new URL(page.url()).pathname === '/orc-village/gatekeeper', page.url());
    check('...headed with the Gatekeeper and its own emoji',
        (await text('#main .header-name')) === '🌀 Gatekeeper', await text('#main .header-name'));
    check('...who lists the one route out of an Orc\'s village, and its fee',
        (await text('#routes-table tbody')) === '🏰 Town of Gludio 🪙 6,000', await text('#routes-table tbody'));
    check('...under a button that says it goes back until something is picked',
        (await text('#teleport-form button')) === 'Return', await text('#teleport-form button'));
    await page.selectOption('#teleport-form select', 'gludio');
    await page.waitForFunction(() => document.querySelector('#teleport-form button').textContent.includes('Teleport'));
    check('...and says it teleports once it is', (await text('#teleport-form button')) === '🌀 Teleport',
        await text('#teleport-form button'));
    await page.click('#teleport-form button');
    await page.waitForSelector('#flash.alert-danger', { timeout: 5000 });
    check('an empty purse cannot pay the Gatekeeper', (await text('#flash')).includes('cannot pay'),
        await text('#flash'));
    check('...and goes nowhere', new URL(page.url()).pathname === '/orc-village/gatekeeper', page.url());

    await typeAdena();
    await adena(10000);
    check('typing adena in a debug build puts 10,000 in the purse', (await state()).adena === 10000);
    await teleport('gludio');
    await page.waitForURL(`${BASE}/gludio`, { timeout: 5000 });
    await adena(4000);
    check('the Gatekeeper sends it to Gludio for 6,000, leaving 4,000', (await state()).adena === 4000);
    check('...where it stands in Gludio', (await text('#main .header-name')) === '🏰 Town of Gludio',
        await text('#main .header-name'));

    await page.selectOption('#travel-form select', 'gatekeeper');
    await page.click('#travel-form button');
    await onScreen('gatekeeper');
    await teleport('dion');
    await page.waitForSelector('#flash.alert-danger', { timeout: 5000 });
    check('4,000 is not the 4,100 Dion costs', new URL(page.url()).pathname === '/gludio/gatekeeper'
        && (await state()).adena === 4000, page.url());
    await typeAdena();
    await adena(14000);
    check('...and typing it again fills the purse again', (await state()).adena === 14000);
    await teleport('dion');
    await page.waitForURL(`${BASE}/dion`, { timeout: 5000 });
    await adena(9900);
    check('so it goes on to Dion, with 9,900 left', (await state()).adena === 9900);

    await page.selectOption('#travel-form select', 'gatekeeper');
    await page.click('#travel-form button');
    await onScreen('gatekeeper');
    const closed = await page.$$eval('#teleport-form option[disabled]', os => os.map(o => o.value));
    check('Dion\'s Gatekeeper lists Giran and its harbour, not open yet',
        closed.join(',') === 'giran,giran-harbor', closed.join(','));
    await teleport('');
    await onScreen('town');
    check('...and its empty choice is the way back into town', new URL(page.url()).pathname === '/dion', page.url());

    // ---- the hour, forced: the real one is never read, so this holds at any time of day -------
    const night = () => page.locator('#effects [data-effect-id="night"]').count();
    await page.evaluate(() => document.activeElement?.blur());
    await page.keyboard.type('night');
    await page.waitForSelector('#effects [data-effect-id="night"]', { timeout: 5000 });
    check('typing night in a debug build brings the night, whatever the hour', await night() === 1);
    await page.keyboard.type('day');
    await page.waitForSelector('#effects [data-effect-id="night"]', { state: 'detached', timeout: 5000 });
    check('...and typing day lifts it', await night() === 0);

    // ---- the bars, moved on demand: XP does not regenerate, so it is what is waited on --------
    const xpNow = (want) => page.waitForFunction((want) => document.querySelector(
        '#sidebar .bar-track:has(#xp-bar)')?.getAttribute('aria-valuenow') === String(want),
        want, { timeout: 5000 });
    await page.keyboard.type('half');
    await xpNow(34);
    const halved = await state();
    check('typing half sets the XP bar halfway to Level 2, and leaves HP and MP short',
        halved.level === 1 && halved.xpRequired === 68
        && halved.health < halved.maxHealth && halved.mp < halved.maxMp, JSON.stringify(halved));
    await page.keyboard.type('lvl');
    await page.waitForFunction(() =>
        document.querySelector('#sidebar [data-key="level"]')?.dataset.value === '2', null, { timeout: 5000 });
    const levelled = await state();
    check('...and typing lvl reaches Level 2 exactly, both bars refilled as rules §12 says',
        levelled.xp === 0 && levelled.health === levelled.maxHealth && levelled.mp === levelled.maxMp,
        JSON.stringify(levelled));
    await page.keyboard.type('maxlvl');
    await page.waitForFunction(() =>
        document.querySelector('#sidebar [data-key="level"]')?.dataset.value === '80', null, { timeout: 5000 });
    const topped = await state();
    check('...and typing maxlvl reaches the last level, both bars refilled',
        topped.health === topped.maxHealth && topped.mp === topped.maxMp, JSON.stringify(topped));

    // ---- the temporary Quit, for trying every set from one browser --------------------------
    check('the town\'s dropdown offers no Quit, being the game\'s',
        await page.locator('#travel-form option[value="quit"]').count() === 0);
    for (const combo of ['q', 'Control+c', 'Control+c'])
        await page.keyboard.press(combo);
    // Answered or not, a quit would have landed well inside this: there is nothing to wait for.
    await page.waitForTimeout(500);
    check('Q alone, or Ctrl+C twice, is not Ctrl+Q', (await state()).screen === 'town',
        (await state()).screen);
    await page.keyboard.press('Control+q');
    await onScreen('start');
    check('Ctrl+Q goes back to game start, with no character', (await state()).started === false);
    await create('AgainBot', 3, 'fighter');
    check('...and the same browser starts another at once',
        (await text('#main .header-name')) === '🌑 Dark Elven Village', await text('#main .header-name'));

    check('no request to the app failed', failedRequests.length === 0, failedRequests.join(' | '));
    check('no console errors', consoleErrors.length === 0, consoleErrors.join(' | '));
} catch (err) {
    check(`walkthrough threw: ${err.message}`, false);
} finally {
    await browser.close();
}

console.log(failures.length === 0 ? '\nAll checks passed.' : `\n${failures.length} check(s) failed.`);
process.exit(failures.length === 0 ? 0 : 1);
