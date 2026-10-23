/**
 * One character, made and stood in its village, end to end: `mix e2e walkthrough`. It asserts only
 * what the browser alone can see; every starting set is races.mjs's.
 */
import { readdirSync, readFileSync } from 'node:fs';
import { chromium } from 'playwright';
import { BASE, reporter, traceAudio, traceRefocus, controls, marginsLeftAtEnds, freshStart, lifted } from './helpers.mjs';

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
// What a reload draws before any script (the page fetched again and parsed, never run) beside what
// is on screen, both read by one reader so they compare whole: a reload is served as it was left.
const servedShownOn = (on, selector) => on.evaluate(async (sel) => {
    const read = (root) => [...root.querySelectorAll(sel)].map((el) => ({
        id: el.id, text: el.textContent.trim(), title: el.getAttribute('title'),
        expanded: el.getAttribute('aria-expanded'), sort: el.getAttribute('aria-sort'),
        class: [...el.classList].sort().join(' '),
    }));
    const html = await (await fetch(location.href)).text();
    const served = read(new DOMParser().parseFromString(html, 'text/html'));
    const shown = read(document);
    return { served, same: JSON.stringify(served) === JSON.stringify(shown), detail: JSON.stringify({ served, shown }) };
}, selector);
const servedShown = (selector) => servedShownOn(page, selector);

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

    // ---- the twinned formatters agree -------------------------------------------------------
    // The hooks format their own frames and countdowns, so each Format function and its JavaScript
    // twin read one table in test/fixtures; Elixir reads them in format_test.exs.
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
    const sidePanels = () => page.locator('#sidebar > .panel').evaluateAll((panels) => panels.map((p) => p.id).slice(1).join());
    check('...and no Consumables panel while none are carried, the Inventory following the vitals',
        await sidePanels() === 'inventory', await sidePanels());
    check('...resting, as a character with nothing to fight always is',
        await page.locator('#effects [data-effect-id="resting"]').count() === 1);

    // ---- a flash belongs to its arrival, and to nothing after it -----------------------------
    await page.click('#header-link');
    await page.waitForSelector('#main .alert', { state: 'detached', timeout: 5000 }).catch(() => {});
    check('a flash does not survive coming back to the same screen',
        await page.locator('#main .alert').count() === 0);

    // ---- muting is the browser's, and the toggle says so in its own chime --------------------
    const keptCookie = async () => (await context.cookies()).find(c => c.name === '_mini_lineage_kept');
    await page.click('#sound-toggle');
    check('muting flips the toggle', await page.textContent('#sound-toggle') === '🔇');
    check('...and plays nothing', (await page.evaluate(() => window.__notes.splice(0))).length === 0);
    const kept = await keptCookie();
    check('...kept in a cookie of the browser\'s own, for the whole site, sameSite Lax and readable by the page',
        kept?.path === '/' && kept.sameSite === 'Lax' && !kept.httpOnly && kept.expires > Date.now() / 1000 + 300 * 86400,
        JSON.stringify(kept));
    const mutedToggle = await servedShown('#sound-toggle');
    check('...which the next page is served with, muted just as the hook drew it',
        mutedToggle.same && mutedToggle.served[0]?.text === '🔇', mutedToggle.detail);
    await page.reload({ waitUntil: 'domcontentloaded' });
    await page.waitForSelector('.phx-connected', { timeout: 8000 });
    check('...and a refresh keeps it muted', await page.textContent('#sound-toggle') === '🔇');
    await page.click('#sound-toggle');
    check('unmuting flips it back', await page.textContent('#sound-toggle') === '🔊');
    const soundingToggle = await servedShown('#sound-toggle');
    check('...served sounding again, and with nothing left to keep, the cookie gone',
        soundingToggle.same && soundingToggle.served[0]?.text === '🔊' && await keptCookie() === undefined,
        soundingToggle.detail);
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
        sections.join('|') === '🧟 BrowserBot of Orc Ancestry|✨ Buffs & Debuffs|⚖️ Combat Stats|🎓 Learned Skills'
        && await page.locator('#sidebar').count() === 0, sections.join('|'));
    const known = await page.$$eval('#screen [id^="skill-"]', (els) => els.map(el => el.id).join(','));
    check('...its Learned Skills panel naming what it knows, the one spell a Mystic starts with',
        known === 'skill-chill-flame', known);
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

    // ---- a second-tier panel folds at any width, and stays as the reader left it -------------
    const inventory = page.locator('#inventory .panel-body');
    const folded = () => inventory.waitFor({ state: 'hidden', timeout: 3000 }).then(() => true, () => false);
    const openInventory = await servedShown('#inventory .panel-toggle');
    check('the Inventory opens unfolded beside the main panel, as it is served',
        openInventory.same && openInventory.served[0]?.expanded === 'true' && await inventory.isVisible(),
        openInventory.detail);
    await page.click('#inventory .panel-toggle');
    check('...until its header folds it, there as anywhere', await folded());
    const foldedInventory = await servedShown('#inventory .panel-toggle');
    check('...after which the page is served with it folded, so a reload moves nothing',
        foldedInventory.same && foldedInventory.served[0]?.expanded === 'false', foldedInventory.detail);
    await page.reload({ waitUntil: 'domcontentloaded' });
    await page.waitForSelector('.phx-connected', { timeout: 8000 });
    check('...and a refresh keeps the fold, the panel being the reader\'s own', await folded());
    const desktop = page.viewportSize();
    await page.setViewportSize({ width: 320, height: 800 });
    check('...as does a phone, where it stacks under the main panel', await folded());
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
    check('...raising the gold alert above what the debug build says',
        /Congratulations! You have reached Level 2\./.test(await text('#levelled.alert-triumph'))
        && await page.evaluate(() => document.querySelector('#levelled').nextElementSibling?.id === 'flash'),
        await text('#levelled'));
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
    check('the Halls list this run as the reader\'s own, still living, with no day it fell',
        await mine.count() === 1 && await mine.getAttribute('data-fate') === 'living'
        && await mine.locator('time').count() === 0, rowId);
    check('...and the Halls draw no sidebar', await page.locator('#sidebar').count() === 0);

    // Somebody else watching the Halls sees the run's purse move, pushed rather than reloaded.
    const watcher = await freshStart(browser);
    await watcher.page.goto(`${BASE}/highscores`, { waitUntil: 'domcontentloaded' });
    await watcher.page.waitForSelector('.phx-connected', { timeout: 8000 });
    const purse = `#${rowId} [data-key="adena-${rowId.slice(4)}"]`;
    const before = Number(await watcher.page.getAttribute(purse, 'data-value'));
    // Every row that starts a sweep, from before the run's own tab reloads, so its dot going off and
    // on again is watched too.
    await watcher.page.evaluate(() => {
        window.__stirred = [];
        new MutationObserver((records) => {
            for (const r of records)
                if (r.target.hasAttribute('data-stirred')) window.__stirred.push(r.target.id);
        }).observe(document.querySelector('#halls-rows'),
            { subtree: true, attributes: true, attributeFilter: ['data-stirred'] });
    });
    await page.goto(BASE, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('.phx-connected', { timeout: 8000 });
    await onScreen('town');
    // A sweep by a composited property, or one that fills, lifted the board's text and it blinked.
    let pushed = false;
    const swept = await lifted(watcher.context, watcher.page, async () => {
        await page.keyboard.type('adena');
        pushed = await watcher.page.waitForFunction(
            ([sel, want]) => document.querySelector(sel)?.dataset.value === String(want),
            [purse, before + 10000], { timeout: 5000 }).then(() => true, () => false);
    }, '#screen');
    check('...and another browser on the Halls sees the purse grow without reloading', pushed,
        String(await watcher.page.getAttribute(purse, 'data-value')));
    const stirred = await watcher.page.evaluate(() => window.__stirred);
    check('...its row alone sweeping, once, for the purse and never for the dot',
        stirred.length === 1 && stirred[0] === rowId, stirred.join(', '));
    check('...and the sweep lifts nothing on the board onto a layer of its own',
        swept.length === 0, swept.join(', '));
    await watcher.context.close();

    // ---- the debug build's Quit, kept for trying every set from one browser -----------------
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
    // An icon fading in unclipped lifted the panel's buttons, which blinked as each one arrived.
    const arriving = await lifted(context, page, async () => {
        await page.selectOption('#travel-form select', 'hunt');
        await page.click('#travel-form button');
        await onScreen('hunt');
        await page.waitForSelector('#effects [data-effect-id="combat"]', { timeout: 5000 });
    }, '#screen');
    check('the combat icon fades in lifting nothing on the page but itself',
        arriving.length > 0 && arriving.every(el => el.startsWith('span.effect-icon')), arriving.join(', '));
    // A finished fade that fills, or a hover's shimmer, kept the Retreat beside Hunt lifted.
    await page.waitForFunction(() => [...document.querySelectorAll('#effects .effect-icon')]
        .every(el => el.getAnimations().every(a => a.playState === 'finished')), null, { timeout: 5000 });
    const resting = await lifted(context, page, () => page.hover('#hunt-button'), '#screen');
    check('...and once it stands, the pointer on Hunt shimmers it lifting nothing at all',
        resting.length === 0, resting.join(', '));
    check('the village\'s way out reaches its hunting ground, at its own address',
        new URL(page.url()).pathname.split('/').length === 3, page.url());
    check('...headed with the ground\'s name', (await text('#main h2.header-name')).length > 3,
        await text('#main h2.header-name'));
    check('...with the sidebar beside it', await page.locator('#sidebar').count() === 1);
    check('going out meets nothing until the hunter looks for it, but is combat at once',
        await page.locator('#fight').count() === 0
        && await page.locator('#effects [data-effect-id="combat"]').count() === 1);
    check('...and its orders ask nothing about potions while none is carried',
        await page.locator('#orders').count() === 1 && await page.locator('#potion-order').count() === 0);
    check('...where the button says Hunt beside Retreat', await text('#hunt-button') === '⚔️ Hunt'
        && await text('#retreat-button') === 'Retreat', `${await text('#hunt-button')} / ${await text('#retreat-button')}`);
    await page.click('#hunt-button');
    await page.waitForSelector('#fight-outcome', { timeout: 5000 });
    check('hunting is the first fight, which says what fell', /cut down/.test(await text('#fight-outcome')),
        await text('#fight-outcome'));
    const firstHead = await page.evaluate(() => [...document.querySelectorAll('#fight-log .entry-head')]
        .map((head) => head.textContent.replace(/\s+/g, ' ').trim()).find((head) => head.startsWith('Round')) ?? '');
    check('...in the Fight Log, a panel of its own under the ground\'s, a round a row headed by both sides\' HP, not in an alert',
        await page.locator('#flash').count() === 0
        && await page.locator('#screen > .panel:nth-child(2) #fight-log').count() === 1
        && (await text('#fight h2')).includes('Fight Log')
        && /^Round 1 • 0\.0s\s*Foe \d+% • You \d+%$/.test(firstHead), firstHead);
    const opening = await page.evaluate(() => document.querySelector('#fight-log > li:first-child').className);
    check('...opening on an Encounter washed blue or an Ambush washed red', /^(encounter|ambush)$/.test(opening), opening);
    const firstMove = await text('#hunt-button');
    check('...after which the button names where the hunt goes next', firstMove !== '⚔️ Hunt' && firstMove.startsWith('⚔️ '),
        firstMove);
    // Rules §20: a new line after every fight, so the button row is measured at its widest here.
    const oneRow = () => page.evaluate(() =>
        document.querySelector('#hunt-button').getBoundingClientRect().top
        === document.querySelector('#retreat-button').getBoundingClientRect().top);
    const wide = page.viewportSize();
    await page.setViewportSize({ width: 360, height: 800 });
    const phoneRow = await oneRow();
    await page.setViewportSize(wide);
    check('...on one row with Retreat, on a desktop and a 360px phone', await oneRow() && phoneRow);
    const orders = page.locator('#orders .panel-body');
    const ordersFolded = () => orders.waitFor({ state: 'hidden', timeout: 3000 }).then(() => true, () => false);
    await page.click('#orders .panel-toggle');
    check('the Battle Orders under the fight fold on their header', await ordersFolded());
    await page.click('#hunt-button');
    await page.waitForFunction((shown) =>
        document.querySelector('#hunt-button')?.textContent.trim() !== shown, firstMove, { timeout: 5000 });
    check('hunting again fights again, still on the ground, and names somewhere new',
        (await state()).screen === 'hunt' && await page.locator('#fight-outcome').count() === 1);
    check('...the orders staying folded through it', await ordersFolded());
    const foldedOrders = await servedShown('#orders .panel-toggle');
    check('...and served folded', foldedOrders.same && foldedOrders.served[0]?.expanded === 'false', foldedOrders.detail);
    await page.click('#orders .panel-toggle');
    check('...until they are opened again', await orders.isVisible());
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
    await page.selectOption('#trader-form select', 'trader-weapon');
    await page.click('#trader-form button');
    await onScreen('trader-weapon');
    check('the weapons trader is a page of its own, Iria showing a Dark Fighter daggers and nothing else',
        new URL(page.url()).pathname === '/dark-elf-village/traders/weapon'
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
    check('...in a success alert', await page.locator('#flash.alert-success').count() === 1);
    await adena(wallet - 768);
    check('...for its price, 768', (await state()).adena === wallet - 768, String((await state()).adena));
    check('...and the dropdown goes back to its placeholder, so a second click buys nothing more',
        await page.inputValue('#buy-form select') === '' && await text('#buy-form button') === 'Return',
        `${await page.inputValue('#buy-form select')} / ${await text('#buy-form button')}`);
    const shelf = (await state()).screen;
    await page.click('#purse a');
    await onScreen('inventory');
    check('the inventory lists everything carried, what is equipped highlighted, the Combat Stats beside it folding',
        await page.locator('#items tr.owned').count() === 3 && await page.locator('#combat-stats .panel-toggle').count() === 1,
        String(await page.locator('#items tr.owned').count()));
    const byName = page.locator('#items thead button.sort', { hasText: 'Item' });
    const unsorted = await rowIds('#items');
    await byName.click();
    await page.waitForSelector('#items th[aria-sort="ascending"]:has-text("Item")', { timeout: 5000 });
    const sortedIds = await rowIds('#items');
    const sortedRows = await servedShown('#items tbody tr, #items th');
    // Compared rather than reloaded: a reload would close the inventory onto the town, not the shelf.
    check('the inventory remembers its sort, so a reload is served the rows in the order the reader chose',
        sortedIds !== unsorted && sortedRows.same, sortedRows.detail);
    await page.locator('#items thead button.sort', { hasText: 'Slot' }).click();
    await page.waitForSelector('#items th[aria-sort="ascending"]:has-text("Slot")', { timeout: 5000 });
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

    await page.selectOption('#travel-form select', 'trader');
    await page.click('#travel-form button');
    await onScreen('trader');
    await page.selectOption('#trader-form select', 'trader-armour');
    await page.click('#trader-form button');
    await onScreen('trader-armour');
    // The stock is still sorted by name from the Weapon Trader, so only what any sort keeps is checked.
    const lightRows = (await rowIds('#shelf-light-armour')).split(',');
    check('the Armour Trader shows a Fighter shields first, then its shirts and pants together as light armour',
        (await page.locator('#stock tbody').evaluateAll((shelves) => shelves.map((s) => s.id))).join() ===
            'shelf-shields,shelf-light-armour'
        && ['stock-leather-shirt', 'stock-leather-pants'].every((id) => lightRows.includes(id)),
        lightRows.join());
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
    check('...which the sidebar counts among its Consumables, now between the vitals and the Inventory, and leaves out of the Inventory',
        await sidePanels() === 'consumables,inventory'
        && /^🧪 Lesser Healing\s*×10$/.test(await text('#consumables .panel-body'))
        && await page.locator('#consumables [title="Lesser Healing Potion"]').count() === 1
        && await page.locator('#consumables [data-key^="consumable-"][data-value="10"]').count() === 1
        && !/Potion/.test(await text('#inventory')),
        `${await text('#consumables')} / ${await text('#inventory')}`);
    // A fight drinks below 70% at the start of every round, so at half HP it drinks at least once,
    // whatever it meets; the sidebar's figure moves, which is what makes AnimatedValues count it.
    // Twenty, as climbing back to 70% has drunk five, so the stack outlasts any fight.
    const stackKey = await page.getAttribute('#consumables [data-key^="consumable-"]', 'data-key');
    await page.selectOption('#travel-form select', 'trader');
    await page.click('#travel-form button');
    await onScreen('trader');
    await page.selectOption('#trader-form select', 'trader-magic');
    await page.click('#trader-form button');
    await onScreen('trader-magic');
    await page.selectOption('#buy-form select', 'Lesser Healing Potion|10');
    await page.click('#buy-form button');
    await page.waitForFunction((key) =>
        document.querySelector(`#consumables [data-key="${key}"]`)?.dataset.value === '20', stackKey, { timeout: 5000 });
    await page.click('#header-link');
    await onScreen('town');
    await page.evaluate(() => document.activeElement?.blur());
    await page.keyboard.type('half');
    await page.waitForFunction(() => {
        const figure = (key) => Number(document.querySelector(`#sidebar [data-key="${key}"]`)?.dataset.value);
        return figure('hp') < figure('max-hp') * 0.7;
    }, null, { timeout: 5000 });
    await page.selectOption('#travel-form select', 'hunt');
    await page.click('#travel-form button');
    await onScreen('hunt');
    check('coming back to the ground draws the last fight fought there, the button saying Hunt again',
        await page.locator('#fight #fight-outcome').count() === 1 && await text('#hunt-button') === '⚔️ Hunt',
        await text('#hunt-button'));

    // ---- the battle orders (rules §20, §26) -----------------------------------------------------
    const share = (kind) => page.getAttribute(`#${kind}-share`, 'aria-valuetext');
    check('the ground\'s orders drink potions below half HP to begin with, on a slider',
        await share('potion') === 'below 50% HP' && await text('#potion-share-value') === 'below 50% HP',
        await share('potion'));
    check('...with no heal orders for a character that knows no heal',
        await page.locator('#pull-share').count() === 0);
    await page.focus('#potion-share');
    await page.keyboard.press('ArrowLeft');
    const lowered = await page.locator('#potion-share-value', { hasText: 'below 30%' })
        .waitFor({ timeout: 5000 }).then(() => true, () => false);
    check('...and the player lowers the share a stop from the keyboard, the slider keeping focus and no alert',
        lowered && await page.evaluate(() => document.activeElement?.id) === 'potion-share'
        && await page.locator('#screen .alert').count() === 0, await text('#potion-share-value'));
    // A value column sized to its text resized the track under a drag each time the server answered.
    const widths = [];
    for (const [stop, value] of [['0', 'never'], ['1', 'below 30%'], ['2', 'below 50%'], ['3', 'below 70%']]) {
        await page.locator('#potion-share').fill(stop);
        await page.locator('#potion-share-value', { hasText: value }).waitFor({ timeout: 5000 });
        widths.push(await page.$eval('#potion-share', el => el.getBoundingClientRect().width));
    }
    const clipped = await page.$eval('#potion-share-value', el => el.scrollWidth > el.clientWidth);
    check('...the slider as long at every stop, whatever its value says, and the value never clipped',
        new Set(widths).size === 1 && !clipped, `${widths.join(', ')}${clipped ? ', clipped' : ''}`);

    // The last fight is already drawn here, so the new one is known by the button naming a move.
    await page.click('#hunt-button');
    await page.waitForFunction(() =>
        document.querySelector('#hunt-button')?.textContent.trim() !== '⚔️ Hunt', null, { timeout: 5000 });
    // Read, not waited for: a stack drunk dry leaves no figure, and that is no count.
    const left = await page.evaluate((key) =>
        document.querySelector(`#consumables [data-key="${key}"]`)?.dataset.value, stackKey);
    check('a fight that drinks moves the stack\'s own figure in the sidebar, which counts it down',
        left !== undefined && Number(left) < 20, `${left} left under ${stackKey}`);
    await page.click('#retreat-button');
    await onScreen('town');
    await page.waitForSelector('#effects [data-effect-id="combat"]', { state: 'detached', timeout: 10000 });

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
    const learnedPanel = () => page.locator('#screen h2', { hasText: 'Learned Skills' }).count();
    check('...to a Fighter that starts knowing its weapon\'s skill, in the Learned Skills panel beside it, which folds',
        await learnedPanel() === 1 && await page.locator('#learned-skills .panel-toggle').count() === 1
        && await text('#skill-mortal-blow .skill') === 'Mortal Blow 1',
        await text('#skill-mortal-blow'));
    check('...saying how often it lands and its reuse, worked for this character',
        /landing \d+\.\d% of the time, for \d+ MP\. Reuse \d+\.\ds\./.test(await text('#skill-mortal-blow'))
        && Number(await page.getAttribute('[data-key="skill-mortal-blow-lands"]', 'data-value')) > 0,
        await text('#skill-mortal-blow'));
    check('...listing each skill\'s next line alone, never the ones after it',
        await page.locator('#lesson-mortal-blow-1').count() === 0 &&
        await page.locator('#lesson-mortal-blow-3').count() === 0);
    check('...with the level it requires and its SP named in full on hover',
        await page.getAttribute('#lessons th:nth-child(2)', 'title') === 'Level Required' &&
        await page.getAttribute('#lessons th:nth-child(3)', 'title') === 'Skill Points');
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
    check('...a line needing a weapon saying so after its name, a spell nothing',
        await text('#lesson-mortal-blow-4 td.name .muted') === 'Needs a dagger' &&
        await page.locator('#lesson-drain-health-1 td.name .muted').count() === 0, await text('#lesson-drain-health-1'));
    check('...shelving the skills fought with apart from the masteries, as a trader shelves its goods',
        await text('#shelf-active tr.shelf th') === 'Active' &&
        await text('#shelf-passive tr.shelf th') === 'Passive' &&
        await page.locator('#shelf-passive #lesson-armor-mastery-1').count() === 1 &&
        await page.locator('#shelf-passive #lesson-weapon-mastery-1').count() === 1 &&
        await page.locator('#shelf-passive #lesson-anti-magic-1').count() === 1 &&
        await page.locator('#shelf-active #lesson-armor-mastery-1').count() === 0,
        await text('#lessons'));
    check('...and the dropdown grouped the same',
        (await page.locator('#learn-form optgroup').evaluateAll((groups) => groups.map((g) => g.label))).join() === 'Active,Passive' &&
        await text('#learn-form optgroup[label="Passive"] option[value="Armor Mastery|1"]') === 'Pick 🪖 Armor Mastery 1');
    await page.selectOption('#learn-form select', 'Armor Mastery|1');
    await page.locator('#learn-form button', { hasText: '📖 Learn' }).waitFor({ timeout: 5000 });
    await page.click('#learn-form button');
    await page.waitForSelector('#lesson-armor-mastery-1', { state: 'detached', timeout: 5000 });
    check('...a mastery learned reading as what it adds, never as a formula or a reuse',
        await text('#skill-armor-mastery') === '🪖 Armor Mastery 1 • +9 P. Def.' &&
        await page.locator('#lesson-armor-mastery-2').count() === 1,
        await text('#skill-armor-mastery'));

    // ---- a skill left unused (rules §20) --------------------------------------------------------
    await page.click('#header-link');
    await onScreen('town');
    await page.selectOption('#travel-form select', 'hunt');
    await page.click('#travel-form button');
    await onScreen('hunt');
    // Read here and checked at the guild below: nothing between them earns any.
    const ordersSp = await page.getAttribute('#orders-footer [data-key="orders-sp"]', 'data-value');
    await page.click('#orders .panel-toggle');
    await orders.waitFor({ state: 'hidden', timeout: 3000 });
    await page.click('#header-link');
    await onScreen('town');
    await page.selectOption('#travel-form select', 'hunt');
    await page.click('#travel-form button');
    await onScreen('hunt');
    check('the orders folded on the ground are drawn folded on coming back to it',
        await page.getAttribute('#orders .panel-toggle', 'aria-expanded') === 'false');
    await page.click('#orders .panel-toggle');
    await orders.waitFor({ state: 'visible', timeout: 3000 });
    check('the orders use every skill to begin with, each on a switch',
        await page.getAttribute('#use-mortal-blow', 'aria-checked') === 'true');
    check('...and a mastery is no order to give',
        await page.locator('#use-armor-mastery').count() === 0);
    // Each track ends its column, so the tracks line up down it whatever the names' lengths.
    const ends = await page.$$eval('#skills-order .switch', els => els.map(el =>
        [el.getBoundingClientRect().width, el.getBoundingClientRect().right - el.querySelector('.switch-track').getBoundingClientRect().right]));
    check('...each switch as wide as the next and its track ending it, so the tracks line up',
        ends.length > 0 && new Set(ends.map(([w]) => w)).size === 1 && ends.every(([, gap]) => Math.abs(gap) < 0.5),
        JSON.stringify(ends));
    // Beside the sliders' label column, "Drink Healing Potion" left room for one switch a line.
    const skillsLeft = await page.$eval('#skills-order .switches', el =>
        el.getBoundingClientRect().left - document.querySelector('#orders-footer .sp').getBoundingClientRect().left);
    check('...with no label of their own, the switches taking the panel\'s width from where the SP starts',
        await page.locator('#skills-order .stat-label').count() === 0 && Math.abs(skillsLeft) < 0.5, skillsLeft);
    const nameColour = () => page.$eval('#use-mortal-blow .skill', el => getComputedStyle(el).color);
    const lit = await nameColour();
    await page.click('#use-mortal-blow');
    await page.waitForSelector('#use-mortal-blow[aria-checked="false"]', { timeout: 5000 });
    check('...and a chip switched off mutes its name, and keeps the keyboard rather than handing it to the hunt',
        await nameColour() !== lit
        && await page.evaluate(() => document.activeElement?.id) === 'use-mortal-blow');
    await page.click('#header-link');
    await onScreen('town');
    await page.click('#character-name a');
    await onScreen('character');
    check('...where it is learned too',
        await page.locator('#skill-mortal-blow.locked', { hasText: 'Left unused, by your orders.' }).count() === 1,
        await text('#skill-mortal-blow'));
    await page.click('#header-link');
    await onScreen('town');
    await page.selectOption('#travel-form select', 'hunt');
    await page.click('#travel-form button');
    await onScreen('hunt');
    await page.click('#use-mortal-blow');
    const used = await page.locator('#use-mortal-blow[aria-checked="true"]')
        .waitFor({ timeout: 5000 }).then(() => true, () => false);
    check('...until it is switched on again', used, await page.getAttribute('#use-mortal-blow', 'aria-checked'));
    // Drawn by the link rule itself, so it reads as the purse's Open does and can't drift from it.
    const drawn = (sel) => page.$eval(sel, el => {
        const c = getComputedStyle(el);
        return [c.color, c.fontSize, c.textDecorationLine, c.textUnderlineOffset, c.transition].join(' / ');
    });
    await page.locator('#orders').scrollIntoViewIfNeeded();
    check('the orders moved from the start, the footer\'s Reset puts them back, drawn as the purse\'s Open',
        await page.locator('#orders-footer #orders-reset:not([disabled])').count() === 1
        && await drawn('#orders-reset') === await drawn('#purse a'),
        `${await drawn('#orders-reset')} against ${await drawn('#purse a')}`);
    await page.click('#orders-reset');
    const reset = await page.locator('#orders-reset[disabled]')
        .waitFor({ timeout: 5000 }).then(() => true, () => false);
    // Muted as a `.muted` beside it is, once the link's colour fade has run, and without the line
    // that says it can be followed.
    const quiet = await page.waitForFunction(() => {
        const el = document.getElementById('orders-reset');
        const muted = el.parentElement.appendChild(Object.assign(document.createElement('span'), { className: 'muted' }));
        const same = getComputedStyle(muted).color === getComputedStyle(el).color;
        muted.remove();
        return same && getComputedStyle(el).textDecorationLine === 'none';
    }, null, { timeout: 5000 }).then(() => true, () => false);
    check('...back to the start, after which it waits for the next change, disabled and muted, with no alert',
        reset && quiet
        && await page.getAttribute('#potion-share', 'aria-valuetext') === 'below 50% HP'
        && await page.locator('#screen .alert').count() === 0, await page.getAttribute('#potion-share', 'aria-valuetext'));
    // A flip across the defaults once swapped the footer's Reset for plain text beside the SP, and the
    // SP blinked; a flip may now change attributes in the footer and nothing else.
    await page.evaluate(() => {
        window.__footer = [];
        window.__footerObserver = new MutationObserver(rs => rs.forEach(r => window.__footer.push(
            r.type === 'attributes' ? `@${r.attributeName}` : r.type)));
        window.__footerObserver.observe(document.getElementById('orders-footer'),
            { subtree: true, childList: true, attributes: true, characterData: true });
    });
    for (const state of ['false', 'true']) {
        await page.click('#use-mortal-blow');
        await page.waitForSelector(`#use-mortal-blow[aria-checked="${state}"]`, { timeout: 5000 });
    }
    const footerChanges = await page.evaluate(() => { window.__footerObserver.disconnect(); return window.__footer; });
    check('...and a flip across the defaults rebuilds nothing in the footer beside the SP, only the Reset\'s attributes',
        footerChanges.length > 0 && footerChanges.every(c => c.startsWith('@')), footerChanges.join(', '));
    // A knob slid by `transform` lifted the rows after it, and the SP blinked for the slide.
    const slid = await lifted(context, page, async () => {
        await page.click('#use-mortal-blow');
        await page.waitForSelector('#use-mortal-blow[aria-checked="false"]', { timeout: 5000 });
    }, '#orders');
    check('...and a switch slides without lifting anything in the orders onto a layer of its own',
        slid.length === 0, slid.join(', '));
    await page.click('#use-mortal-blow');
    await page.waitForSelector('#use-mortal-blow[aria-checked="true"]', { timeout: 5000 });
    await page.click('#retreat-button');
    await onScreen('town');
    // The tour below waits on regen ticks, which combat withholds.
    await page.waitForSelector('#effects [data-effect-id="combat"]', { state: 'detached', timeout: 10000 });

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
    await browse('trader-weapon');
    await holdEach();
    await home();
    await hurt();
    await travel('trader', 'trader');
    await browse('trader-sell');
    await holdEach();
    await home();
    await travel('guild', 'guild');
    check('the orders\' footer showed the SP the guild counts, so nobody walks there to see it',
        await page.getAttribute('[data-key="guild-sp"]', 'data-value') === ordersSp, ordersSp);
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

    // ---- a death (rules §21), in a browser of its own ---------------------------------------------
    // Left 1 HP before every fight, since a fight can still be won at 1 HP (a blow that kills first, a
    // monster that misses), so one soon ends the run; the suite asserts on what a death draws, never
    // on which fight it came in.
    const grave = await freshStart(browser);
    const g = grave.page;
    const gc = controls(g);
    g.on('console', m => { if (m.type() === 'error') consoleErrors.push(m.text()); });
    await gc.create('Doomed', 0, 'fighter');
    await g.selectOption('#travel-form select', 'hunt');
    await g.click('#travel-form button');
    await gc.onScreen('hunt');
    const ground = new URL(g.url()).pathname;
    let fights = 0;
    for (; fights < 40 && await g.locator('#death-line').count() === 0; fights++) {
        await g.evaluate(() => document.activeElement?.blur());
        await g.keyboard.type('frail');
        await g.waitForFunction(() =>
            document.querySelector('#sidebar [data-key="hp"]')?.dataset.value === '1', null, { timeout: 5000 });
        // A fight lived through renames the button, never to the line it showed; a death removes it.
        const shown = await gc.text('#hunt-button');
        await g.click('#hunt-button');
        await g.waitForFunction((was) => document.querySelector('#death-line')
            || document.querySelector('#hunt-button')?.textContent.replace(/\s+/g, ' ').trim() !== was,
            shown, { timeout: 5000 });
    }
    check(`a run left 1 HP before each fight dies within 40 of them (${fights})`,
        await g.locator('#death-line').count() === 1);
    const colour = (sel) => g.$eval(sel, (el) => getComputedStyle(el).color);
    const hpRed = await g.evaluate(() => {
        const probe = document.createElement('span');
        probe.className = 'hp';
        document.body.append(probe);
        const red = getComputedStyle(probe).color;
        probe.remove();
        return red;
    });
    check('a death keeps the run on the ground it fell on, its end told in red',
        new URL(g.url()).pathname === ground && await colour('#death-line .deaths') === hpRed,
        `${g.url()} ${await colour('#death-line .deaths')}`);
    const washed = await g.$eval('#fight-outcome', (el) => [
        getComputedStyle(el).backgroundColor.replace(/\s/g, ''),
        getComputedStyle(document.documentElement).getPropertyValue('--wash-danger').replace(/\s/g, ''),
        el.querySelector('.entry-head').textContent.trim()]);
    check('...its fight ending in Defeat, washed red', washed[2] === 'Defeat' && washed[0] === washed[1],
        washed.join(' | '));
    check('...a ghost with no Hunt, no Retreat and no orders, offering the Monument and Play Again',
        await g.locator('#hunt-button, #retreat-button, #orders').count() === 0
        && await g.locator('#effects [data-effect-id]').count() === 1
        && await g.locator('#effects [data-effect-id="ghost"]').count() === 1
        && (await gc.text('#monument-button')) === '🏛️ Monument of Heroes'
        && (await gc.text('#restart-button')) === 'Play Again');
    check('...its panel headed Game Over in place of the ground, and the document title with it',
        (await gc.text('#main .header-name')) === '🪦 Game Over' && await g.title() === 'Mini Lineage - Game Over',
        `${await gc.text('#main .header-name')} | ${await g.title()}`);
    check('...neither of which takes the keyboard on arrival', await g.evaluate(() =>
        !['monument-button', 'restart-button'].includes(document.activeElement?.id)));
    const fallenServed = await servedShownOn(g, '#death-line, #fight-outcome, #monument-button, #restart-button');
    check('...served as it is shown', fallenServed.same && fallenServed.served.length === 4, fallenServed.detail);
    const line = await gc.text('#death-line');
    await g.reload({ waitUntil: 'domcontentloaded' });
    await g.waitForSelector('.phx-connected', { timeout: 8000 });
    check('...and a reload draws the same line and the same fight',
        await gc.text('#death-line') === line && await g.locator('#fight-outcome.defeat').count() === 1);
    await g.goto(`${BASE}/${ground.split('/')[1]}`, { waitUntil: 'domcontentloaded' });
    await g.waitForSelector('.phx-connected', { timeout: 8000 });
    await gc.onScreen('hunt');
    check('...the town it stood in sending it back there', new URL(g.url()).pathname === ground, g.url());
    await g.click('#purse a');
    await gc.onScreen('inventory');
    check('...its inventory read but offering nothing to do',
        await g.locator('#inventory-form option:not([value=""])').count() === 0, await gc.text('#inventory-form'));
    check('...but the way back to its Game Over',
        (await gc.text('#inventory-form option[value=""]')) === '🚪 Game Over'
        && (await gc.text('#inventory-form button')) === 'Return', await gc.text('#inventory-form'));
    await g.click('#inventory-form button');
    await gc.onScreen('hunt');
    await g.click('#monument-button');
    await gc.onScreen('highscores');
    check('the Monument opens on the run\'s own lineage', new URL(g.url()).pathname === '/highscores/human', g.url());
    // The board coalesces its writes, so the death may reach it a beat after the page does.
    await g.waitForSelector('#halls-rows tr.mine[data-fate="fallen"] time.date', { timeout: 5000 });
    const fell = await g.$eval('#halls-rows tr.mine[data-fate="fallen"] time.date',
        (el) => [el.dateTime, el.textContent.trim(), el.closest('tr').textContent.includes('💀')]);
    check('...where the run carries the day it fell, written out, in place of a skull',
        Date.now() - Date.parse(fell[0]) < 600_000 && /^\d{1,2} [A-Z][a-z]{2} \d{4}$/.test(fell[1]) && !fell[2],
        fell.join(' | '));
    await g.click('#header-link');
    await gc.onScreen('hunt');
    await g.click('#restart-button');
    await gc.onScreen('start');
    check('...and Play Again goes to game start, with no character',
        new URL(g.url()).pathname === '/' && (await gc.state()).started === false);
    await grave.context.close();

    check('no request to the app failed', failedRequests.length === 0, failedRequests.join(' | '));
    check('no console errors', consoleErrors.length === 0, consoleErrors.join(' | '));
} catch (err) {
    check(`walkthrough threw: ${err.message}`, false);
} finally {
    await browser.close();
}

console.log(failures.length === 0 ? '\nAll checks passed.' : `\n${failures.length} check(s) failed.`);
process.exit(failures.length === 0 ? 0 : 1);
