/**
 * Drives the real game in a real browser. Unit tests and jsdom cannot see CSP enforcement, stale
 * bundles, or a background push wiping the panel — every browser-only bug in this project lived
 * in exactly that gap.
 *
 * Usage: start the isolated server (`game/e2e/serve.sh`), then
 *   LD_LIBRARY_PATH=~/.local/lib/playwright-deps node game/e2e/walkthrough.mjs
 */
import { chromium } from 'playwright';

const BASE = process.env.E2E_BASE_URL ?? 'http://localhost:4002';

const failures = [];
const check = (label, ok, detail = '') => {
    console.log(`${ok ? '✅' : '❌'} ${label}${detail ? ` — ${detail}` : ''}`);
    if (!ok)
        failures.push(label);
};

const browser = await chromium.launch();
const page = await browser.newPage();

const consoleErrors = [];
const failedRequests = [];
page.on('console', m => { if (m.type() === 'error') consoleErrors.push(m.text()); });
page.on('pageerror', e => consoleErrors.push(`pageerror: ${e.message}`));
page.on('requestfailed', r => {
    // Google Fonts may be unreachable offline; that is not the app's fault.
    if (r.url().startsWith(BASE))
        failedRequests.push(`${r.method()} ${r.url()} :: ${r.failure()?.errorText}`);
});

const screen = () => page.getAttribute('#screen', 'data-screen');

try {
    // Never `networkidle`: the LiveView websocket stays open, so it never settles.
    await page.goto(BASE, { waitUntil: 'domcontentloaded' });

    check('the page renders a screen', await screen() === 'start');

    // Proves the carried-over stylesheet actually loaded AND matched, not merely 200'd. The
    // background lives on `body`; `#app` is the flex container the layout rules key off.
    const bg = await page.locator('body').evaluate(el => getComputedStyle(el).backgroundColor);
    const display = await page.locator('#app').evaluate(el => getComputedStyle(el).display);
    const font = await page.locator('.header-title').evaluate(el => getComputedStyle(el).fontFamily);
    check('the carried-over CSS is applied', bg !== 'rgba(0, 0, 0, 0)', `body background ${bg}`);
    check('...including the layout rules', display === 'flex', `#app display ${display}`);
    check('...including the display font', /Cinzel|Silkscreen/i.test(font), font);

    // The bug this exists for: a CSP that silently breaks the app's own transport.
    await page.waitForSelector('.phx-connected', { timeout: 5000 });
    check('LiveView connects through the CSP', true);

    // ---- the character outlives the connection ----------------------------------------------
    await page.fill('input[name="name"]', 'BrowserBot');
    await page.selectOption('select[name="race_id"]', '2'); // Elf
    await page.click('button[type="submit"]');
    await page.waitForSelector('#screen[data-screen="home"]', { timeout: 5000 });

    const nameOf = () => page.textContent('#main [data-role="name"]');
    const adenaOf = () => page.textContent('#main [data-role="adena"]');
    check('creating a character lands on Town', await screen() === 'home');
    check('...with the chosen name', await nameOf() === 'BrowserBot', await nameOf());
    check('...and the Elf starting purse', await adenaOf() === '450', await adenaOf());

    // The bug this exists for: state living only in the view, lost the moment the socket drops.
    await page.reload({ waitUntil: 'domcontentloaded' });
    await page.waitForSelector('.phx-connected', { timeout: 5000 });
    check('a hard refresh finds the same character', await nameOf() === 'BrowserBot', await nameOf());
    check('...still on Town, not back at Game Start', await screen() === 'home');

    check('no request to the app failed', failedRequests.length === 0, failedRequests.join(' | '));
    check('no console errors', consoleErrors.length === 0, consoleErrors.join(' | '));
} catch (err) {
    check(`walkthrough threw: ${err.message}`, false);
} finally {
    await browser.close();
}

console.log(failures.length === 0 ? '\nAll browser checks passed.' : `\n${failures.length} check(s) failed.`);
process.exit(failures.length === 0 ? 0 : 1);
