/**
 * One character against a production image, driven by e2e/release.sh: what only a release has — digested
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
const { onScreen } = controls(page);

try {
    const response = await page.goto(`${BASE}/`, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('.phx-connected', { timeout: 10000 });
    const refused = consoleErrors.filter(e => /Content Security Policy/i.test(e));
    check('the socket connects, and the CSP refuses nothing', refused.length === 0, refused.join(' | '));

    const csp = response.headers()['content-security-policy'] ?? '';
    check('the CSP refuses eval', csp.includes("script-src") && !csp.includes('unsafe-eval'), csp);
    const sheet = await page.evaluate(() =>
        [...document.styleSheets].map(s => s.href ?? '').find(h => h.includes('/assets/css/')));
    check('the stylesheet is the digested one', /app-[0-9a-f]{32}\.css/.test(sheet ?? ''), sheet);
    check('the footer names the commit',
        (await page.textContent('#copyright')).includes(process.env.APP_VERSION ?? '?'));
    check('...and no build label', await page.locator('#copyright [class^="build-"]').count() === 0);

    check('a release writes no name in for the player',
        await page.inputValue('#main input[name="name"]') === '');
    await page.fill('#main input[name="name"]', 'ReleaseBot');
    await page.selectOption('#main select[name="race_id"]', '1');
    await page.selectOption('#main select[name="path"]', 'fighter');
    await page.click('#main button[type="submit"]');
    await onScreen('town');
    const cookie = (await page.context().cookies()).find(c => c.name === '_mini_lineage_key');
    check('the session cookie is secure and httpOnly', cookie?.secure && cookie?.httpOnly);
    check('...and the character stands in its village',
        (await page.textContent('#main .header-name'))?.trim() === '🏕️ Orc Village');
    check('...at its own address', new URL(page.url()).pathname === '/orc-village', page.url());
    check('a release listens for no typed keys', await page.locator('#dev-keys').count() === 0);
    await page.evaluate(() => document.activeElement?.blur());
    await page.keyboard.type('adena');
    // Answered or not, a reply would have landed well inside this: there is nothing to wait for.
    await page.waitForTimeout(500);
    check('...so typing adena leaves the purse empty',
        await page.getAttribute('#sidebar [data-key="adena"]', 'data-value') === '0');
    // The real hour may be either, so what is checked is that typing changes nothing.
    const night = await page.locator('#effects [data-effect-id="night"]').count();
    await page.keyboard.type(night ? 'day' : 'night');
    await page.keyboard.type('lvl');
    await page.keyboard.press('Control+q');
    await page.waitForTimeout(500);
    check('...nor does typing the hour change it',
        await page.locator('#effects [data-effect-id="night"]').count() === night);
    check('...nor typing lvl the level',
        await page.getAttribute('#sidebar [data-key="level"]', 'data-value') === '1');
    check('...nor does Ctrl+Q end the character',
        (await page.textContent('#main .header-name'))?.trim() === '🏕️ Orc Village');
    check('no console errors', consoleErrors.length === 0, consoleErrors.join(' | '));
} catch (err) {
    check(`release check threw: ${err.message}`, false);
} finally {
    await browser.close();
}

process.exit(failures.length === 0 ? 0 : 1);
