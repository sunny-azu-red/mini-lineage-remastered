/**
 * One turn against a production image, driven by e2e/release.sh: what only a release has — digested
 * assets, its CSP, the secure cookie, the stamped footer — and that its socket connects at all.
 */
import { chromium } from 'playwright';
import { BASE, reporter, controls } from './helpers.mjs';

const { check, failures } = reporter();
const browser = await chromium.launch();
const page = await browser.newPage();
const consoleErrors = [];
page.on('console', m => { if (m.type() === 'error') consoleErrors.push(m.text()); });
page.on('pageerror', e => consoleErrors.push(`pageerror: ${e.message}`));
const { state, onScreen, travel } = controls(page);

try {
    const response = await page.goto(`${BASE}/`, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('.phx-connected', { timeout: 10000 });
    check('the socket connects', true);

    const csp = response.headers()['content-security-policy'] ?? '';
    check('the CSP refuses eval', csp.includes("script-src") && !csp.includes('unsafe-eval'), csp);
    const sheet = await page.evaluate(() =>
        [...document.styleSheets].map(s => s.href ?? '').find(h => h.includes('/assets/css/')));
    check('the stylesheet is the digested one', /app-[0-9a-f]{32}\.css/.test(sheet ?? ''), sheet);
    check('the footer names the commit',
        (await page.textContent('#copyright')).includes(process.env.APP_VERSION ?? '?'));
    check('...and no build label', await page.locator('#copyright [class^="build-"]').count() === 0);

    await page.fill('#main input[name="name"]', 'ReleaseBot');
    await page.selectOption('#main select[name="race_id"]', '1');
    await page.click('#main button[type="submit"]');
    await onScreen('home');
    const cookie = (await page.context().cookies()).find(c => c.name === '_mini_lineage_key');
    check('the session cookie is secure and httpOnly', cookie?.secure && cookie?.httpOnly);

    // Arriving fights, and the dice may end the run: either screen is the server answering.
    await travel('battle');
    check('a fight resolves', ['battle', 'death'].includes((await state()).screen));
    check('no console errors', consoleErrors.length === 0, consoleErrors.join(' | '));
} catch (err) {
    check(`release check threw: ${err.message}`, false);
} finally {
    await browser.close();
}

process.exit(failures.length === 0 ? 0 : 1);
