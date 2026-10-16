/**
 * One character, made and stood in its village, end to end: `mix e2e walkthrough`. It asserts only
 * what the browser alone can see; every starting set is races.mjs's.
 */
import { readdirSync, readFileSync } from 'node:fs';
import { chromium } from 'playwright';
import { BASE, reporter, traceAudio, traceRefocus, controls, marginsLeftAtEnds, freshStart } from './helpers.mjs';

const { check, failures } = reporter();
const browser = await chromium.launch();
const context = await browser.newContext();
await traceAudio(context);
await traceRefocus(context);
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
// The ids of a table's or a shelf's item rows, leaving out a shelf's heading.
const rowIds = async (rows) =>
    (await page.locator(`${rows} tr[id]`).evaluateAll((trs) => trs.map((tr) => tr.id))).join();

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
    const tenths = JSON.parse(readFileSync('test/fixtures/tenths_format.json', 'utf8')).cases;
    const offTenths = await page.evaluate(
        (rows) => rows
            .filter(([value, expected]) => window.__tenthsFigure(value) !== expected)
            .map(([value, expected]) => `${value}: ${window.__tenthsFigure(value)} != ${expected}`),
        tenths,
    );
    check('...and writes tenths exactly as the server does', offTenths.length === 0, offTenths.join(' | '));
    const timers = JSON.parse(readFileSync('test/fixtures/effect_timer.json', 'utf8'));
    const offTimers = await page.evaluate(
        ({ badge, spoken }) => [
            ...badge.filter(([ms, expected]) => window.__timerLabel(ms) !== expected)
                .map(([ms, expected]) => `${ms}: ${window.__timerLabel(ms)} != ${expected}`),
            ...spoken.filter(([ms, expected]) => window.__remainingLabel(ms) !== expected)
                .map(([ms, expected]) => `${ms}: ${window.__remainingLabel(ms)} != ${expected}`),
        ],
        timers,
    );
    check('...and counts an effect down exactly as the server does', offTimers.length === 0, offTimers.join(' | '));
    // A server clock can step (WSL2's moves 3.6s every half minute), so a later duration for a
    // countdown already running must not move it, and a new countdown starts from its own.
    const stepped = await page.evaluate(() => {
        const el = document.createElement('div');
        el.innerHTML = '<span data-remaining-ms="30000" data-timer-key="walkthrough-1"></span>';
        const timer = el.firstChild;
        const hook = Object.assign(Object.create(window.__EffectTimers), { el });
        hook.mounted();
        const first = timer.textContent;
        timer.dataset.remainingMs = '33600';
        hook.updated();
        const stepped = timer.textContent;
        timer.dataset.timerKey = 'walkthrough-2';
        timer.dataset.remainingMs = '9000';
        hook.updated();
        const recast = timer.textContent;
        hook.destroyed();
        return `${first} ${stepped} ${recast}`;
    });
    check('...holding a countdown to its first duration when a later one disagrees, until a new one starts',
        stepped === '30 30 9', stepped);

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
    check('...with the line that sent it out from there',
        /You chose the 🧟 Orc Mystic and set out from 🏕️ Orc Village/.test(await text('#main .alert')),
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
        labels.join(',') === 'HP,MP,XP' && (await text('#xp-bar ~ .bar-text')) === '0%',
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
        sections.join('|') === '🧟 BrowserBot of Orc Ancestry|✨ Buffs & Debuffs|⚖️ Combat Stats|🎓 Learned Skills|📜 Battle Orders'
        && await page.locator('#sidebar').count() === 0, sections.join('|'));
    const known = await page.$$eval('#screen [id^="skill-"]', (els) => els.map(el => el.id).join(','));
    check('...its Learned Skills panel naming what it knows, the one spell a Mystic starts with',
        known === 'skill-chill-flame' && await page.locator('#no-skills').count() === 0, known);
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
        (await text('#effect-resting')).startsWith('💤 Resting • Between fights'),
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
    check('...who says by name where you can be sent from',
        (await text('#gatekeeper-intro')).startsWith('Tamil the Gatekeeper can send you on from 🏕️ Orc Village'),
        await text('#gatekeeper-intro'));
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
    check('an empty purse cannot pay the Gatekeeper, who names the fee in gold',
        (await text('#flash')).includes('Tamil will not send you on for less than 🪙 6,000 Adena') &&
        await text('#flash .adena') === '🪙 6,000 Adena',
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
        [...closed].sort().join(',') === 'giran,giran-harbor', closed.join(','));
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

    check('Dion has no hunting ground, so its way out offers none',
        await page.locator('#travel-form option[value="hunt"]').count() === 0);

    // ---- the Halls ------------------------------------------------------------------------------
    await page.goto(`${BASE}/highscores`, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('.phx-connected', { timeout: 8000 });
    await onScreen('highscores');
    const mine = page.locator('#halls-rows tr.mine');
    const rowId = await mine.getAttribute('id');
    check('the Halls list this run as the reader\'s own, still living',
        await mine.count() === 1 && await mine.getAttribute('data-fate') === 'living', rowId);
    check('...and the Halls draw no sidebar', await page.locator('#sidebar').count() === 0);

    // Somebody else watching the Halls sees the run's purse move, pushed rather than reloaded.
    const watcher = await freshStart(browser);
    await watcher.page.goto(`${BASE}/highscores`, { waitUntil: 'domcontentloaded' });
    await watcher.page.waitForSelector('.phx-connected', { timeout: 8000 });
    const purse = `#${rowId} [data-key="adena-${rowId.slice(4)}"]`;
    const before = Number(await watcher.page.getAttribute(purse, 'data-value'));
    await page.goto(BASE, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('.phx-connected', { timeout: 8000 });
    await onScreen('town');
    await page.keyboard.type('adena');
    const pushed = await watcher.page.waitForFunction(
        ([sel, want]) => document.querySelector(sel)?.dataset.value === String(want),
        [purse, before + 10000], { timeout: 5000 }).then(() => true, () => false);
    check('...and another browser on the Halls sees the purse grow without reloading', pushed,
        String(await watcher.page.getAttribute(purse, 'data-value')));
    await watcher.context.close();

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
        (await text('#main .header-name')) === '🌑 Dark Elf Village', await text('#main .header-name'));

    // ---- the hunt (rules §17, §20) ---------------------------------------------------------------
    // Raised to the last level first, where no monster on the ladder can kill, so the click's effect is certain even
    // though the fight is not: the suite asserts on what the click did, never on a roll.
    await page.evaluate(() => document.activeElement?.blur());
    await page.keyboard.type('maxlvl');
    await page.waitForFunction(() =>
        document.querySelector('#sidebar [data-key="level"]')?.dataset.value === '80', null, { timeout: 5000 });
    await page.selectOption('#travel-form select', 'hunt');
    await page.click('#travel-form button');
    await onScreen('hunt');
    check('the village\'s way out reaches its hunting ground, at its own address',
        new URL(page.url()).pathname.split('/').length === 3, page.url());
    check('...headed with the ground\'s name', (await text('#main h2.header-name')).length > 3,
        await text('#main h2.header-name'));
    check('...with the sidebar beside it', await page.locator('#sidebar').count() === 1);
    check('going out meets nothing until the hunter looks for it, but is combat at once',
        await page.locator('#fight-log').count() === 0
        && await page.locator('#effects [data-effect-id="combat"]').count() === 1);
    await page.click('#hunt-button');
    await page.waitForSelector('#fight-outcome', { timeout: 5000 });
    check('looking for action is the first fight, which says what fell', /cut down/.test(await text('#fight-outcome')),
        await text('#fight-outcome'));
    check('...on the page itself, round by round with both sides\' HP, not in an alert',
        await page.locator('#flash').count() === 0 && /Round 1: .* HP, you at/.test(await text('#fight-log')),
        (await text('#fight-log')).slice(0, 160));
    await page.click('#hunt-button');
    await page.waitForSelector('#fight-outcome', { timeout: 5000 });
    check('looking for more action fights again, still on the ground', (await state()).screen === 'hunt');
    await page.click('#retreat-button');
    await onScreen('town');
    check('...and retreating goes back to the village', (await state()).screen === 'town');
    // Rules §20: In Combat lingers 5 seconds after the ground, counted down over its icon by
    // EffectTimers between pushes, then rest resumes on the next tick.
    const combatTimer = '#effects [data-effect-id="combat"] .effect-timer';
    await page.waitForSelector(combatTimer, { timeout: 5000 });
    const firstSecond = Number(await text(combatTimer));
    check('...where In Combat counts down the seconds until rest over its icon',
        firstSecond >= 1 && firstSecond <= 5, await text(combatTimer));
    const ticked = await page.waitForFunction(
        ({ selector, was }) => Number(document.querySelector(selector)?.textContent) < was,
        { selector: combatTimer, was: firstSecond }, { timeout: 3000 }).then(() => true, () => false);
    check('...in the browser, between pushes', ticked,
        await page.locator(combatTimer).textContent({ timeout: 500 }).catch(() => 'gone'));
    const counted = Number(await text(combatTimer));
    await page.click('#purse a');
    await onScreen('inventory');
    const reopened = await page.locator(combatTimer).textContent({ timeout: 500 }).catch(() => null);
    check('...and opening the inventory carries on the count rather than starting it again',
        reopened === null || Number(reopened) <= counted, `${counted} then ${reopened}`);
    await page.click('#purse a');
    await onScreen('town');
    const rested = await page.waitForSelector('#effects [data-effect-id="combat"]', { state: 'detached', timeout: 10000 })
        .then(() => true, () => false);
    check('...and then the hunter rests again', rested
        && await page.locator('#effects [data-effect-id="resting"]').count() === 1);

    // ---- the trader and the inventory (rules §23, §24) ----------------------------------------
    check('the sidebar names the weapons and armour equipped, unlabelled, and one link opens the inventory, underlining only its word',
        /Dagger/.test(await text('#equipped-weapons'))
        && await page.locator('#equipped-armour .stat-value').count() === 2
        && await page.locator('#inventory .stat-label').count() === 0
        && await page.locator('#inventory a').count() === 1 && await text('#purse a') === 'Open',
        await text('#inventory'));
    await page.click('#header-link');
    await onScreen('town');
    const savings = (await state()).adena;
    await page.evaluate(() => document.activeElement?.blur());
    await page.keyboard.type('adena');
    await adena(savings + 10000);
    const wallet = savings + 10000;
    await page.selectOption('#travel-form select', 'trader');
    await page.click('#travel-form button');
    await onScreen('trader');
    check('the village\'s four traders are named, each by what they sell',
        (await text('#trader-intro')).startsWith('Iria sells weapons, Payne armour and shields, and Minaless and Vollodos jewellery and potions'),
        await text('#trader-intro'));
    await page.selectOption('#trader-form select', 'trader-weapons');
    await page.click('#trader-form button');
    await onScreen('trader-weapons');
    check('the weapons trader is a page of its own, Iria showing a Dark Fighter daggers and nothing else',
        new URL(page.url()).pathname === '/dark-elf-village/trader/weapons'
        && (await text('#trader-intro')).startsWith('Iria deals in no weapons made by clumsy Humans')
        && (await page.locator('#screen table').evaluateAll((tables) => tables.map((t) => t.id))).join() === 'stock'
        && (await rowIds('#shelf-daggers')) === 'stock-bone-dagger,stock-knife,stock-dirk,stock-throwing-knife'
        && await page.locator('#stock tr.shelf, #buy-form optgroup').count() === 0,
        await text('#screen'));
    check('...each weapon saying how many hands it takes',
        (await text('#stock-bone-dagger')).startsWith('🔪 Bone Dagger ✋'), await text('#stock-bone-dagger'));
    await page.click('#stock button[phx-value-key="name"]');
    await page.waitForSelector('#stock th[aria-sort="ascending"] button[phx-value-key="name"]', { timeout: 5000 });
    check('...sorting its shelf by name, the dropdown following it',
        (await rowIds('#shelf-daggers')) === 'stock-bone-dagger,stock-dirk,stock-knife,stock-throwing-knife'
        && (await page.$$eval('#buy-form option:not([value=""])', (os) => os.map((o) => o.value))).join()
            === 'Bone Dagger,Dirk,Knife,Throwing Knife',
        await rowIds('#shelf-daggers'));
    await page.selectOption('#buy-form select', 'Bone Dagger');
    await page.click('#buy-form button');
    // The debug build's own flash is already up.
    await page.locator('#flash', { hasText: 'Bone Dagger' }).waitFor({ timeout: 5000 }).catch(() => {});
    check('...where a Bone Dagger is bought through the dropdown', /Bone Dagger/.test(await text('#flash')),
        await text('#flash'));
    await adena(wallet - 768);
    check('...for its price, 768', (await state()).adena === wallet - 768, String((await state()).adena));
    check('...and the dropdown goes back to its placeholder, so a second click buys nothing more',
        await page.inputValue('#buy-form select') === '' && await text('#buy-form button') === 'Return',
        `${await page.inputValue('#buy-form select')} / ${await text('#buy-form button')}`);
    const shelf = (await state()).screen;
    await page.click('#purse a');
    await onScreen('inventory');
    check('the inventory lists everything carried, what is equipped highlighted',
        await page.locator('#items tr.owned').count() === 3, String(await page.locator('#items tr.owned').count()));
    check('...in one list grouped by what each item can be given',
        JSON.stringify(await page.$$eval('#inventory-form optgroup', gs => gs.map(g => g.label)))
            === JSON.stringify(['Equip', 'Unequip', 'Destroy']),
        JSON.stringify(await page.$$eval('#inventory-form optgroup', gs => gs.map(g => g.label))));
    const boneDagger = await page.$eval('#inventory-form optgroup[label="Equip"]', (el) =>
        [...el.children].find(o => o.textContent.includes('Bone Dagger'))?.value);
    await page.selectOption('#inventory-form select', boneDagger);
    // The label is the server's answer to the pick, a round trip after it.
    const equip = await page.locator('#inventory-form button', { hasText: /Equip/ })
        .waitFor({ timeout: 5000 }).then(() => true, () => false);
    check('...and picking something under Equip offers to equip it', equip, await text('#inventory-form button'));
    await page.click('#inventory-form button');
    await page.waitForSelector('#items tr.owned:has-text("Bone Dagger")', { timeout: 5000 });
    check('...which it does, highlighting the Bone Dagger', true);
    check('...the Dagger it replaced carried, not lost',
        await page.locator('#items tr:not(.owned) td.name', { hasText: "Squire's Dagger" }).count() === 1);
    check('...and the sidebar beside it names it', /Bone Dagger/.test(await text('#equipped-weapons')),
        await text('#equipped-weapons'));
    check('...where the way in has become the way out', await text('#purse a') === 'Close', await text('#purse a'));
    await page.click('#purse a');
    await onScreen(shelf);
    check('...which closes onto the trader\'s page it was opened from', (await state()).screen === shelf,
        (await state()).screen);
    await page.click('#header-link');
    await onScreen('town');

    // ---- potions (rules §26) --------------------------------------------------------------------
    await page.selectOption('#travel-form select', 'trader');
    await page.click('#travel-form button');
    await onScreen('trader');
    await page.selectOption('#trader-form select', 'trader-magic');
    await page.click('#trader-form button');
    await onScreen('trader-magic');
    check('the Magic Trader keeps necklaces and then potions, Minaless and Vollodos greeting you together',
        (await page.locator('#stock tbody').evaluateAll((shelves) => shelves.map((s) => s.id))).join() ===
            'shelf-necklaces,shelf-potions'
        && /^Minaless .* while Vollodos /.test(await text('#trader-intro')),
        await text('#trader-intro'));
    await page.selectOption('#buy-form select', 'Lesser Healing Potion|10');
    await page.click('#buy-form button');
    await adena(wallet - 768 - 900);
    check('the trader\'s potions are bought by the lot, ten for 900',
        (await state()).adena === wallet - 768 - 900, String((await state()).adena));
    await page.click('#header-link');
    await onScreen('town');
    check('...which the sidebar leaves to the inventory', !/Potion/.test(await text('#inventory')),
        await text('#inventory'));
    await page.click('#character-name a');
    await onScreen('character');
    check('...and the character page\'s orders drink them below half HP to begin with',
        /below 50%/.test(await text('#potion-share')), await text('#potion-share'));
    check('...with no heal orders for a character that knows no heal',
        await page.locator('#heal-pull-share').count() === 0);
    await page.selectOption('#orders-form select', 'potion:30');
    await page.click('#orders-form button');
    const lowered = await page.locator('#potion-share', { hasText: 'below 30%' })
        .waitFor({ timeout: 5000 }).then(() => true, () => false);
    check('...and the player can lower the share', lowered, await text('#potion-share'));
    await page.click('#header-link');
    await onScreen('town');

    // ---- the guild (rules §25) ------------------------------------------------------------------
    check('the town leads to the set\'s own guild by its name',
        await text('#travel-form option[value="guild"]') === 'Pick 📖 Temple of Shilen',
        await text('#travel-form option[value="guild"]'));
    await page.selectOption('#travel-form select', 'guild');
    await page.click('#travel-form button');
    await onScreen('guild');
    check('...at its own address, headed by its name and naming its trainers',
        new URL(page.url()).pathname === '/dark-elf-village/guild' &&
        await page.locator('#screen h2.header-name', { hasText: 'Temple of Shilen' }).count() === 1 &&
        (await text('#guild-intro')).includes('Master Trudy and Master Harant teach'),
        page.url());
    check('the sidebar shows no SP, which only the guild shows',
        await page.locator('#sidebar [data-key="sp"]').count() === 0);
    const sp = () => page.getAttribute('[data-key="guild-sp"]', 'data-value');
    const spBefore = Number(await sp());
    await page.evaluate(() => document.activeElement?.blur());
    await page.keyboard.type('sp');
    await page.waitForFunction((want) =>
        document.querySelector('[data-key="guild-sp"]')?.dataset.value === String(want), spBefore + 10000,
        { timeout: 5000 });
    check('the home village\'s guild teaches the next line of the set\'s own first skill, unmuted, for its SP',
        await page.locator('#lesson-mortal-blow-2[data-status="ready"]:not(.locked)').count() === 1 &&
        await text('#lesson-mortal-blow-2 td.sp') === '100', await text('#lesson-mortal-blow-2'));
    const learnedPanel = () => page.locator('#screen h2.header-name', { hasText: 'Learned Skills' }).count();
    check('...to a Fighter that starts knowing its weapon\'s skill, in the Learned Skills panel beside it',
        await learnedPanel() === 1 && await text('#skill-mortal-blow .skill') === 'Mortal Blow 1',
        await text('#skill-mortal-blow'));
    check('...saying how often it lands and when it is ready again, worked for this character',
        /landing \d+\.\d% of the time, for \d+ MP\. Ready again every \d+\.\d seconds\./.test(await text('#skill-mortal-blow'))
        && Number(await page.getAttribute('[data-key="skill-mortal-blow-lands"]', 'data-value')) > 0,
        await text('#skill-mortal-blow'));
    check('...listing each skill\'s next line alone, never the ones after it',
        await page.locator('#lesson-mortal-blow-1').count() === 0 &&
        await page.locator('#lesson-mortal-blow-3').count() === 0);
    check('...with the level it requires and its SP named in full on hover',
        await page.getAttribute('#lessons th:nth-child(3)', 'title') === 'Level Required' &&
        await page.getAttribute('#lessons th:nth-child(4)', 'title') === 'Skill Points');
    check('...opening on the level each line requires',
        await page.locator('#lessons th[aria-sort="ascending"] button[phx-value-key="learn_at"]').count() === 1);
    await page.click('#lessons button[phx-value-key="sp"]');
    await page.waitForSelector('#lessons th[aria-sort="ascending"] button[phx-value-key="sp"]', { timeout: 5000 });
    check('...sorting on a header, with the keyboard left on that header rather than the dropdown',
        await page.evaluate(() => document.activeElement?.matches('#lessons button[phx-value-key="sp"]')));
    await page.click('#lessons button[phx-value-key="sp"]');
    await page.waitForSelector('#lessons th[aria-sort="descending"] button[phx-value-key="sp"]', { timeout: 5000 });
    await page.selectOption('#learn-form select', 'Mortal Blow|2');
    await page.locator('#learn-form button', { hasText: 'Learn' }).waitFor({ timeout: 5000 });
    await page.click('#learn-form button');
    await page.waitForSelector('#lesson-mortal-blow-2', { state: 'detached', timeout: 5000 });
    check('...the line learned moving into the Learned Skills panel',
        await text('#skill-mortal-blow .skill') === 'Mortal Blow 2', await text('#skill-mortal-blow'));
    check('...and offering the next line by name, as the legacy shop did',
        await text('#learn-form option[value="Mortal Blow|3"]') === 'Pick 🎯 Mortal Blow 3');
    await page.selectOption('#learn-form select', 'Mortal Blow|3');
    const learning = await page.locator('#learn-form button', { hasText: '📖 Learn' })
        .waitFor({ timeout: 5000 }).then(() => true, () => false);
    check('...and the button turns to learning it once picked', learning, await text('#learn-form button'));
    await page.click('#learn-form button');
    await page.waitForSelector('#lesson-mortal-blow-3', { state: 'detached', timeout: 5000 });
    check('...and a lesson is learned through the dropdown, for its SP',
        Number(await sp()) === spBefore + 10000 - 100 - 930, await sp());
    check('...the dropdown and its button both going back to the village, the lesson no longer offered',
        await page.inputValue('#learn-form select') === '' && await text('#learn-form button') === 'Return',
        await text('#learn-form button'));
    check('...and the SP counts down rather than jumping',
        await page.locator('#guild-intro[phx-hook="AnimatedValues"] [data-key="guild-sp"]').count() === 1);
    check('...moving into the Learned Skills panel and offering the next line',
        await text('#skill-mortal-blow .skill') === 'Mortal Blow 3' &&
        await page.locator('#lesson-mortal-blow-4[data-status="ready"]').count() === 1 &&
        await page.locator('#lesson-mortal-blow-5').count() === 0,
        await text('#skill-mortal-blow'));
    check('...each line naming the weapon it needs, a spell any',
        await text('#lesson-mortal-blow-4 td:nth-child(2)') === 'Dagger' &&
        await text('#lesson-drain-health-1 td:nth-child(2)') === 'Any', await text('#lesson-drain-health-1'));

    // ---- a skill left unused (rules §20) --------------------------------------------------------
    await page.click('#header-link');
    await onScreen('town');
    await page.click('#character-name a');
    await onScreen('character');
    check('the orders say every skill is used to begin with',
        await text('#unused-skills') === 'You use every skill you know.', await text('#unused-skills'));
    await page.selectOption('#orders-form select', 'use:false:Mortal Blow');
    await page.click('#orders-form button');
    const unused = await page.locator('#skill-mortal-blow.locked', { hasText: 'Left unused, by your orders.' })
        .waitFor({ timeout: 5000 }).then(() => true, () => false);
    check('...and a skill the orders leave unused is muted where it is learned, and named in the orders',
        unused && /Mortal Blow unused\.$/.test(await text('#unused-skills')), await text('#unused-skills'));
    await page.selectOption('#orders-form select', 'use:true:Mortal Blow');
    await page.click('#orders-form button');
    const used = await page.locator('#skill-mortal-blow:not(.locked)')
        .waitFor({ timeout: 5000 }).then(() => true, () => false);
    check('...until it is ordered used again', used, await text('#skill-mortal-blow'));

    // ---- every dropdown, held open across a regen tick -----------------------------------------
    // The game moves and acts through dropdowns, so a push the player did not ask for must leave an
    // open list open. Every `select_action` in the source is held here, so a new one can't be missed.
    const hurt = async () => {
        await page.evaluate(() => document.activeElement?.blur());
        await page.keyboard.type('half');
        await page.waitForFunction(() => {
            const figure = (key) => Number(document.querySelector(`#sidebar [data-key="${key}"]`)?.dataset.value);
            return figure('hp') < figure('max-hp');
        }, null, { timeout: 5000 });
    };
    const held = new Set();
    const holdEach = async () => {
        const forms = await page.$$eval('#screen form:has(select[phx-hook="SelectAction"])', fs => fs.map(f => f.getAttribute('id')));
        for (const form of forms) {
            await page.click(`#${form} select`);
            // A blur shuts the list, and so does a focus() it already has (on Windows), the select
            // being moved out and back in, or its options being rewritten.
            await page.evaluate((form) => {
                window.__shut = [];
                const select = document.querySelector(`#${form} select`);
                window.__moved = new MutationObserver((records) => {
                    for (const r of records) {
                        if ([...r.removedNodes].some(n => n.contains(select))) window.__shut.push('moved');
                        else if (select.contains(r.target)) window.__shut.push(`rebuilt ${r.type} ${r.attributeName ?? ''}`);
                    }
                });
                window.__moved.observe(document.getElementById('screen'),
                    { subtree: true, childList: true, attributes: true, characterData: true });
            }, form);
            // The socket's next push, read off the socket because not every page draws the bars.
            await page.evaluate(() => new Promise((resolve, reject) => {
                const socket = window.liveSocket.socket;
                const ref = socket.onMessage((message) => {
                    if (message.event !== 'diff') return;
                    socket.off([ref]);
                    requestAnimationFrame(() => resolve());
                });
                setTimeout(() => reject(new Error('no regen tick within 8s')), 8000);
            }));
            const shut = await page.evaluate(() => { window.__moved.disconnect(); return window.__shut; });
            check(`#${form}, held open, is left alone by a regen tick`, shut.length === 0, shut.join('; '));
            await page.keyboard.press('Escape');
            held.add(form);
        }
    };
    const travel = async (place, screen) => {
        await page.selectOption('#travel-form select', place);
        await page.click('#travel-form button');
        await onScreen(screen);
    };
    const browse = async (part) => {
        await page.selectOption('#trader-form select', part);
        await page.click('#trader-form button');
        await onScreen(part);
    };
    const home = async () => {
        await page.click('#header-link');
        await onScreen('town');
    };
    await home();
    await hurt();
    await holdEach();
    await travel('gatekeeper', 'gatekeeper');
    await holdEach();
    await home();
    await travel('trader', 'trader');
    await holdEach();
    await browse('trader-weapons');
    await holdEach();
    await home();
    await hurt();
    await travel('trader', 'trader');
    await browse('trader-sell');
    await holdEach();
    await home();
    await travel('guild', 'guild');
    await holdEach();
    await home();
    await hurt();
    await page.click('#purse a');
    await onScreen('inventory');
    await holdEach();
    await home();
    await hurt();
    await page.click('#character-name a');
    await onScreen('character');
    await holdEach();
    const declared = readdirSync('lib/mini_lineage_web', { recursive: true })
        .filter(f => /\.(ex|heex)$/.test(f))
        .flatMap(f => [...readFileSync(`lib/mini_lineage_web/${f}`, 'utf8')
            .matchAll(/<\.select_action\b[\s\S]*?\sid="([^"]+)"/g)].map(m => m[1]));
    const missed = declared.filter(id => !held.has(id));
    check(`...every dropdown in the source among them (${declared.length})`,
        declared.length > 0 && missed.length === 0, `not held: ${missed.join(', ')}`);

    // ---- a weapon skill without its weapon (rules §23) ------------------------------------------
    await page.click('#header-link');
    await onScreen('town');
    await page.click('#purse a');
    await onScreen('inventory');
    const dagger = await page.$eval('#inventory-form optgroup[label="Unequip"]', (el) =>
        [...el.children].find(o => o.textContent.includes('Bone Dagger'))?.value);
    await page.selectOption('#inventory-form select', dagger);
    await page.locator('#inventory-form button', { hasText: 'Unequip' }).waitFor({ timeout: 5000 });
    await page.click('#inventory-form button');
    await page.waitForSelector('#items tr.owned:has-text("Bone Dagger")', { state: 'detached', timeout: 5000 });
    await page.click('#header-link');
    await onScreen('town');
    await page.click('#character-name a');
    await onScreen('character');
    const muted = (sel) => page.$eval(sel, (el) => {
        const probe = document.createElement('span');
        probe.className = 'muted';
        document.body.append(probe);
        const want = getComputedStyle(probe).color;
        probe.remove();
        return getComputedStyle(el).color === want;
    });
    check('with nothing in hand, Mortal Blow is muted down to its figures and says what it needs',
        await muted('#skill-mortal-blow .skill') && await muted('#skill-mortal-blow .mp') &&
        /Needs a dagger equipped\.$/.test(await text('#skill-mortal-blow')), await text('#skill-mortal-blow'));

    check('no request to the app failed', failedRequests.length === 0, failedRequests.join(' | '));
    check('no console errors', consoleErrors.length === 0, consoleErrors.join(' | '));
} catch (err) {
    check(`walkthrough threw: ${err.message}`, false);
} finally {
    await browser.close();
}

console.log(failures.length === 0 ? '\nAll checks passed.' : `\n${failures.length} check(s) failed.`);
process.exit(failures.length === 0 ? 0 : 1);
