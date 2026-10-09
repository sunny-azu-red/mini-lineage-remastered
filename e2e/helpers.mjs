/**
 * Shared machinery for the browser suites. They drive the same game through the same controls,
 * and a helper that drifts between them is a bug no run would report.
 */
export const BASE = process.env.E2E_BASE_URL ?? 'http://localhost:4002';

/**
 * The eight starting sets as a browser must find them at level 1, with each race's village and the
 * opening of its perk. The numbers come from docs/rules.md, which rules_test.exs holds the code to.
 */
export const RACES = [
    { id: 0, label: 'Human',    emoji: '🧙', town: 'Talking Island Village', townEmoji: '🏝️', townSlug: 'talking-island',
      perk: 'Humans have no racial perk', classes: {
        fighter: { name: 'Human Fighter', health: 126, mp: 38 },
        mystic:  { name: 'Human Mystic',  health: 98,  mp: 59 } } },
    { id: 1, label: 'Orc',      emoji: '🧟', town: 'Orc Village', townEmoji: '🏕️', townSlug: 'orc-village',
      perk: 'Orcs shrug off sleep, root and poison', classes: {
        fighter: { name: 'Orc Fighter',   health: 141, mp: 39 },
        mystic:  { name: 'Orc Mystic',    health: 104, mp: 60 } } },
    { id: 2, label: 'Elf',      emoji: '🧝', town: 'Elven Village', townEmoji: '🌳', townSlug: 'elven-village',
      perk: 'Elves rest half again as fast', classes: {
        fighter: { name: 'Elven Fighter', health: 113, mp: 39 },
        mystic:  { name: 'Elven Mystic',  health: 96,  mp: 59 } } },
    { id: 3, label: 'Dark Elf', emoji: '🧛', town: 'Dark Elven Village', townEmoji: '🌑', townSlug: 'dark-elven-village',
      perk: 'Dark Elves see better at night', classes: {
        fighter: { name: 'Dark Fighter',  health: 107, mp: 39 },
        mystic:  { name: 'Dark Mystic',   health: 95,  mp: 58 } } },
];

/** Collects results so a run reports every failure rather than dying on the first. */
export function reporter() {
    const failures = [];
    const check = (label, ok, detail = '') => {
        console.log(`${ok ? '✅' : '❌'} ${label}${detail ? ` — ${detail}` : ''}`);
        if (!ok)
            failures.push(label);
    };
    return { check, failures };
}

/** Records every note the page plays: Web Audio produces no output to assert on. */
export const traceAudio = (context) => context.addInitScript(() => {
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

/** The controls a player has, bound to one page. */
export function controls(page) {
    /** The character's live state, read off the one element that mirrors it. */
    const xpTrack = async (attr) => {
        const track = page.locator('#sidebar .bar-track:has(#xp-bar)');
        return await track.count() ? Number(await track.getAttribute(attr)) : null;
    };
    const state = async () => {
        const raw = await page.locator('#screen').evaluate(node => ({ ...node.dataset }));
        // The figures are the sidebar's own `data-value`, which is what the server wrote rather
        // than a frame of the count-up; null on a screen that draws no sidebar.
        const figures = await page.evaluate(() => Object.fromEntries(
            [...document.querySelectorAll('#sidebar [data-key][data-value]')]
                .map(el => [el.dataset.key, Number(el.dataset.value)])));
        return {
            screen: raw.screen,
            started: raw.started === 'true',
            level: figures.level ?? null,
            health: figures.hp ?? null,
            maxHealth: figures['max-hp'] ?? null,
            mp: figures.mp ?? null,
            maxMp: figures['max-mp'] ?? null,
            // The XP bar writes a percentage; what it is a share of is on its track.
            xp: await xpTrack('aria-valuenow'),
            xpRequired: await xpTrack('aria-valuemax'),
            adena: figures.adena ?? null,
        };
    };

    const onScreen = (name) => page.waitForSelector(`#screen[data-screen="${name}"]`, { timeout: 8000 });

    /** Fills in the start form and waits to arrive in town. */
    const create = async (name, raceId, path) => {
        await page.fill('#main input[name="name"]', name);
        await page.selectOption('#main select[name="race_id"]', String(raceId));
        await page.selectOption('#main select[name="path"]', path);
        await page.click('#main button[type="submit"]');
        await onScreen('town');
    };

    const text = async (sel) => (await page.textContent(sel))?.replace(/\s+/g, ' ').trim() ?? '';

    /** The purse as the server last wrote it, once it reads `value`. */
    const adena = (value) => page.waitForFunction(
        (want) => document.querySelector('#sidebar [data-key="adena"]')?.dataset.value === String(want),
        value, { timeout: 5000 });

    return { state, onScreen, create, text, adena };
}

/**
 * A fresh browser on the start page, which is what a new player is: the session names the browser,
 * so a second character needs a second context.
 */
export async function freshStart(browser) {
    const context = await browser.newContext();
    const page = await context.newPage();
    await page.goto(BASE, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('.phx-connected', { timeout: 8000 });
    return { context, page };
}
