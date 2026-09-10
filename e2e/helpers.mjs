/**
 * Shared machinery for the browser suites. Both entry points drive the same game through the same
 * controls, and a helper that drifts between them is a bug neither run would report.
 */
export const BASE = process.env.E2E_BASE_URL ?? 'http://localhost:4002';

/**
 * The four playable lineages, as the UI must present them.
 *
 * These numbers are the newbie blessing's +20 max health and -4 ambush risk already applied, which
 * is what a player actually sees on a fresh character. The balance behind them belongs to
 * balance_golden_test.exs; what is checked here is only that the screens show it.
 */
export const RACES = [
    { id: 0, label: 'Human',     emoji: '🧙', health: 120, adena: 300, crit: 4,  regen: 1, ambush: 4,  plural: 'Humans' },
    { id: 1, label: 'Orc',       emoji: '🧟', health: 170, adena: 250, crit: 0,  regen: 0, ambush: 12, plural: 'Orcs' },
    { id: 2, label: 'Elf',       emoji: '🧝', health: 95,  adena: 450, crit: 8,  regen: 3, ambush: 0,  plural: 'Elves' },
    { id: 3, label: 'Dark Elf',  emoji: '🧛', health: 105, adena: 350, crit: 11, regen: 2, ambush: 1,  plural: 'Dark Elves' },
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
    const state = async () => {
        const raw = await page.locator('#screen').evaluate(node => ({ ...node.dataset }));
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

    const goHome = async () => {
        await page.click('#header-link');
        await onScreen('home');
    };

    /**
     * Label and variant are server-rendered, so selecting is a round trip. Waits, then reads ONCE:
     * two reads let a check fail on a stale button while its message quoted the settled one.
     */
    const buttonSettles = async (expected) => {
        await page.waitForFunction(
            label => document.querySelector('#main form button')?.textContent.trim() === label,
            expected, { timeout: 5000 }).catch(() => {});

        return {
            label: (await page.textContent('#main form button'))?.trim(),
            cls: await page.getAttribute('#main form button', 'class'),
        };
    };

    /**
     * Buys one item and waits for the purse to actually move. Waiting for `#main .alert` returns
     * immediately — the previous purchase's alert is still up — so the next read is stale.
     * Returns false when the purchase was refused.
     */
    const buy = async (itemId) => {
        const before = await page.getAttribute('#screen', 'data-adena');
        await page.selectOption('#main select[name="item_id"]', String(itemId), { timeout: 5000 });
        await page.click('#main form[phx-submit="purchase"] button[type="submit"]');

        return page.waitForFunction(
            (prev) => document.querySelector('#screen')?.dataset.adena !== prev,
            before, { timeout: 5000 }).then(() => true).catch(() => false);
    };

    /** Leaves a shop through its own "🚪 Home Town" option rather than by navigating away. */
    const leaveShop = async () => {
        await page.selectOption('#main select[name="item_id"]', '', { timeout: 5000 });
        await page.click('#main form[phx-submit="purchase"] button[type="submit"]');
        await onScreen('home');
    };

    /**
     * Travels via the Town form, which is how a player actually moves. Waits for the socket first:
     * an unconnected LiveView submits natively. Travelling to the Battleground fights on arrival,
     * which can kill outright, so death also ends the wait.
     */
    const travel = async (to) => {
        await page.waitForSelector('.phx-connected', { timeout: 8000 });
        await onScreen('home');
        await page.selectOption('#main select[name="to"]', to, { timeout: 5000 });
        await page.click('#main form button');

        try {
            await page.waitForFunction((dest) => {
                const screen = document.querySelector('#screen')?.dataset.screen;
                return screen === dest || screen === 'death';
            }, to, { timeout: 8000 });
        } catch {
            throw new Error(`travel to "${to}" never arrived — still on "${(await state()).screen}"`);
        }
    };

    /**
     * Clicks Fight and waits for the result to land. A fatal fight patches to the death screen
     * without counting a battle, so either signal ends the wait.
     */
    const fight = async () => {
        await page.waitForSelector('.phx-connected', { timeout: 8000 });
        const before = await page.getAttribute('#screen', 'data-battles');
        // Matched on the event, not the label: an ambush relabels this button to its own prompt.
        await page.click('#main button[phx-click="fight"]', { timeout: 8000 });
        await page.waitForFunction((prev) => {
            const el = document.querySelector('#screen');
            return !!el && (el.dataset.screen === 'death' || el.dataset.battles !== prev);
        }, before, { timeout: 8000 });
    };

    const boardRows = () => page.locator('#main table.data-table tbody tr').count();
    const activeFilter = async () =>
        (await page.textContent('#main .action-links a.active'))?.replace(/\s+/g, ' ').trim();

    return { state, onScreen, goHome, buttonSettles, buy, leaveShop, travel, fight, boardRows, activeFilter };
}
