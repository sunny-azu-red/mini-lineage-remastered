/**
 * A log in both orders: newest first as the Chronicle reads, oldest first as a chat would. The game
 * has only the first, so this mounts the real `Panel` hook on a log of its own and plays LiveView's
 * patches, which strip what the hook painted. panel_test.exs holds the server to this markup.
 */
import { chromium } from 'playwright';
import { BASE, reporter } from './helpers.mjs';

const { check, failures } = reporter();
const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 800, height: 900 } });
const consoleErrors = [];
page.on('pageerror', e => consoleErrors.push(`pageerror: ${e.message}`));

// A box of 300px and entries of 80, so six arrivals are more than it can show at once.
const BOX = 300;

async function mount(order) {
    await page.evaluate(({ order, BOX }) => {
        window.__hook?.destroyed();
        document.getElementById('harness')?.remove();
        window.__pushed = [];
        window.__hidden = false;
        const chat = order === 'oldest-first';
        const entry = (n) => `<li id="e${n}"><p style="height: 56px">Entry ${n}</p></li>`;
        const held = Array.from({ length: 20 }, (_, i) => entry(i + 1));
        document.body.insertAdjacentHTML('beforeend', `
            <div id="harness" style="position: fixed; top: 0; left: 0; width: 320px; z-index: 99">
              <div id="log" class="panel" data-log="${order}" data-load-older="older_log" data-at-present="log_at_present">
                <div class="panel-header flex"><span class="header-name">Log</span></div>
                <div class="panel-body rows scrolls" style="max-height: ${BOX}px">
                  <ol class="chronicle" data-older-than="1">${(chat ? held : held.reverse()).join('')}</ol>
                </div>
                <button type="button" class="btn btn-sm panel-unread" data-one="new message"
                  data-many="new messages" data-rest="more ${chat ? 'below' : 'above'}" hidden>👁️ <span></span></button>
              </div>
            </div>`);
        const hook = Object.create(window.liveSocket.hooks.Panel);
        hook.el = document.getElementById('log');
        hook.pushEvent = (event, payload, done) => { window.__pushed.push({ event, payload }); done?.(); };
        hook.mounted();
        window.__hook = hook;
    }, { order, BOX });
    await settle();
}

// Two frames: scroll events are delivered before the next one.
const settle = () => page.evaluate(() => new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r))));

// A patch as LiveView makes one: the hook is asked first, the list changes, and everything the hook
// painted is rewritten from the server's markup, which knows nothing of it. Defined in the page, so
// several can land in one task, as they do in a background tab, where no frame runs between them.
const PATCH = (change) => {
    const hook = window.__hook;
    const list = hook.el.querySelector('ol');
    const chat = hook.el.dataset.log === 'oldest-first';
    const entry = (n) => {
        const li = document.createElement('li');
        li.id = `e${n}`;
        li.innerHTML = `<p style="height: 56px">Entry ${n}</p>`;
        return li;
    };
    hook.beforeUpdate();
    if (change.arrive) chat ? list.append(entry(change.arrive)) : list.prepend(entry(change.arrive));
    if (change.older) {
        for (const n of change.older) chat ? list.prepend(entry(n)) : list.append(entry(n));
        delete list.dataset.olderThan;
    }
    // What the server lets go, from the past edge, and whether it holds too many.
    if (change.trim) {
        const items = [...list.children];
        for (const li of chat ? items.slice(0, change.trim) : items.slice(-change.trim)) li.remove();
        list.dataset.olderThan = '1';
    }
    for (const li of list.querySelectorAll('[data-unread]')) li.removeAttribute('data-unread');
    const pill = hook.el.querySelector('.panel-unread');
    pill.hidden = true;
    pill.lastElementChild.textContent = '';
    hook.updated();
};

async function patch(change) {
    await page.evaluate(`(${PATCH})(${JSON.stringify(change)})`);
    await settle();
}

// The entry at the top of the box and where it sits, or where a given one sits now.
const view = (id) => page.evaluate((id) => {
    const box = document.querySelector('#log .panel-body').getBoundingClientRect();
    const li = id ? document.getElementById(id)
        : [...document.querySelectorAll('#log li')].find(li => li.getBoundingClientRect().bottom > box.top);
    return { id: li.id, offset: Math.round(li.getBoundingClientRect().top - box.top) };
}, id);

const state = () => page.evaluate(() => {
    const body = document.querySelector('#log .panel-body');
    const box = body.getBoundingClientRect();
    const pill = document.querySelector('#log .panel-unread');
    const marked = document.querySelectorAll('#log [data-unread]');
    const line = marked[0]?.getBoundingClientRect().bottom;
    return {
        top: body.scrollTop,
        fromEnd: body.scrollHeight - body.clientHeight - body.scrollTop,
        pill: pill.hidden ? null : pill.textContent.trim(),
        marked: [...marked].map(li => `${li.id}:${li.dataset.unread}`),
        line: line === undefined ? null : { fromTop: line - box.top, fromBottom: box.bottom - line },
    };
});

// How far a reader sits from the present, whichever edge that is.
const fromPresent = (s, chat) => (chat ? s.fromEnd : s.top);

// Moves the reader `by` pixels towards the past (negative: towards the present), as a wheel would.
const scrollBy = async (by, chat) => {
    await page.evaluate(([by, chat]) => {
        document.querySelector('#log .panel-body').scrollTop += chat ? -by : by;
    }, [by, chat]);
    await settle();
};

try {
    await page.goto(`${BASE}/races`, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('.phx-connected', { timeout: 8000 });

    for (const order of ['newest-first', 'oldest-first']) {
        const chat = order === 'oldest-first';
        const above = chat ? 'below' : 'above';
        console.log(`\n--- ${order} ---`);
        await mount(order);

        let s = await state();
        check('a log opens at its present', fromPresent(s, chat) <= 2 && !s.pill && !s.marked.length, JSON.stringify(s));

        await patch({ arrive: 21 });
        s = await state();
        check('...and a reader there is shown each arrival, and told of nothing',
            fromPresent(s, chat) <= 2 && !s.pill && !s.marked.length, JSON.stringify(s));

        // ---- away: the line under what arrived, and a pill counting it --------------------------
        await scrollBy(150, chat);
        const reading = await page.evaluate(() => {
            const box = document.querySelector('#log .panel-body').getBoundingClientRect();
            const li = [...document.querySelectorAll('#log li')].find(li => li.getBoundingClientRect().bottom > box.top);
            return { id: li.id, offset: li.getBoundingClientRect().top - box.top };
        });
        await patch({ arrive: 22 });
        s = await state();
        const held = await page.evaluate((id) => document.getElementById(id).getBoundingClientRect().top
            - document.querySelector('#log .panel-body').getBoundingClientRect().top, reading.id);
        check('a reader away from the present keeps the line they were on', Math.abs(held - reading.offset) <= 1,
            `${reading.offset} -> ${held}`);
        // Newest first the line is under the oldest arrival; oldest first, under the last entry held.
        const edge = chat ? 'e21' : 'e22';
        check('...has the line drawn between what they had and what arrived', s.marked.join() === `${edge}:1`, s.marked.join());
        check('...and is told how much, in the singular', s.pill === '👁️ 1 new message', s.pill);

        for (let n = 23; n <= 27; n++) await patch({ arrive: n });
        s = await state();
        check('more arriving joins the same batch, the line staying where the absence began',
            s.marked.join() === `${edge}:6`, s.marked.join());
        check('...and the count grows with it', s.pill === '👁️ 6 new messages', s.pill);

        // ---- the jump: to where they left off, then to the present ------------------------------
        await page.click('#log .panel-unread');
        await settle();
        s = await state();
        const edgeGap = chat ? s.line?.fromTop : s.line?.fromBottom;
        check('the pill takes the reader to where they left off, the line on the past edge of the box',
            edgeGap !== undefined && Math.abs(edgeGap - 24) <= 1, JSON.stringify(s.line));
        const left = Number(s.pill?.match(/\d+/)?.[0]);
        check(`...and counts only what is still ${above}`,
            new RegExp(`^👁️ \\d+ more ${above}$`).test(s.pill ?? '') && left > 0 && left < 6, s.pill);

        await scrollBy(-90, chat);
        s = await state();
        const fewer = Number(s.pill?.match(/\d+/)?.[0] ?? 0);
        check('...which ticks down as the reader reads towards the present', fewer < left, `${left} -> ${fewer}`);

        await page.click('#log .panel-unread');
        await settle();
        s = await state();
        check('a second click goes to the present', fromPresent(s, chat) <= 2 && !s.pill, JSON.stringify(s));
        check('...and the line, reached and read past, is gone', !s.marked.length, s.marked.join());

        // ---- reaching the present by hand, the line kept for whoever scrolls back to it ----------
        await scrollBy(150, chat);
        for (let n = 28; n <= 33; n++) await patch({ arrive: n });
        await page.evaluate((chat) => {
            const body = document.querySelector('#log .panel-body');
            body.scrollTop = chat ? body.scrollHeight : 0;
        }, chat);
        await settle();
        s = await state();
        check('reaching the present by hand is caught up', !s.pill, s.pill);
        check('...but keeps the line, which the reader has not reached yet', s.marked.length === 1, s.marked.join());

        // ---- the server is told whether the reader is at the present, and only as that changes ---
        // There the oldest goes as the newest lands, so a reader following a fight sends nothing.
        await mount(order);
        const told = () => page.evaluate(() =>
            window.__pushed.filter(p => p.event === 'log_at_present').map(p => p.payload.at).join());
        const following = await view('e20');
        for (let n = 21; n <= 23; n++) await patch({ arrive: n, trim: 1 });
        s = await state();
        check('a reader following at the present tells the server nothing as each entry lands',
            (await told()) === '' && fromPresent(s, chat) <= 2, `${await told()} ${JSON.stringify(s)}`);
        const followed = await view('e23');
        check('...and the newest stands where the newest stood as the oldest goes',
            Math.abs(followed.offset - following.offset) <= 1,
            `${JSON.stringify(following)} -> ${JSON.stringify(followed)}`);

        await scrollBy(150, chat);
        await scrollBy(40, chat);
        check('...tells it once as they leave the present, however far they go', (await told()) === 'false',
            await told());
        await page.evaluate((chat) => {
            const body = document.querySelector('#log .panel-body');
            body.scrollTop = chat ? body.scrollHeight : 0;
        }, chat);
        await settle();
        check('...and once as they come back', (await told()) === 'false,true', await told());

        // ---- a hidden tab is away, even at the present ------------------------------------------
        // Six arrive and the tab comes back in one task: a background tab runs no frames, so no
        // scroll event reaches the hook before it is told the reader has returned.
        await mount(order);
        const before = await view();
        await page.evaluate(`
            Object.defineProperty(document, 'hidden', { configurable: true, get: () => window.__hidden });
            window.__hidden = true;
            for (let n = 21; n <= 26; n++) (${PATCH})({ arrive: n });
            window.__hidden = false;
            document.dispatchEvent(new Event('visibilitychange'));
        `);
        await settle();
        s = await state();
        const after = await view(before.id);
        check('a reader whose tab was hidden comes back to the view they left, whatever arrived',
            Math.abs(after.offset - before.offset) <= 1,
            `${JSON.stringify(before)} -> ${JSON.stringify(after)}`);
        check('...with the line where it began, just out of view', s.marked.join() === (chat ? 'e20:6' : 'e21:6'),
            s.marked.join());
        check('...and the pill counting all of it', s.pill === '👁️ 6 new messages', s.pill);

        await page.click('#log .panel-unread');
        await settle();
        s = await state();
        const back = chat ? s.line?.fromTop : s.line?.fromBottom;
        check('...which takes them in from where they left off, not from the newest',
            back !== undefined && Math.abs(back - 24) <= 1 && new RegExp(`^👁️ \\d+ more ${above}$`).test(s.pill ?? ''),
            JSON.stringify(s));
        await page.evaluate(() => { delete document.hidden; });

        // ---- the page before arrives at the past edge, and is not news --------------------------
        await mount(order);
        await page.evaluate((chat) => {
            const body = document.querySelector('#log .panel-body');
            body.scrollTop = chat ? 0 : body.scrollHeight;
        }, chat);
        await settle();
        const pushed = await page.evaluate(() => window.__pushed);
        check('nearing the past edge asks for the page before', pushed.some(p => p.event === 'older_log' && p.payload.before === 1), JSON.stringify(pushed));
        const past = await page.evaluate(() => {
            const box = document.querySelector('#log .panel-body').getBoundingClientRect();
            const li = [...document.querySelectorAll('#log li')].find(li => li.getBoundingClientRect().bottom > box.top);
            return { id: li.id, offset: li.getBoundingClientRect().top - box.top };
        });
        await patch({ older: [0, -1, -2] });
        s = await state();
        const stayed = await page.evaluate((id) => document.getElementById(id).getBoundingClientRect().top
            - document.querySelector('#log .panel-body').getBoundingClientRect().top, past.id);
        check('...which lands without moving the reader off their line', Math.abs(stayed - past.offset) <= 1,
            `${past.offset} -> ${stayed}`);
        check('...or being counted as anything new', !s.pill && !s.marked.length, JSON.stringify(s));
    }

    check('and no script error along the way', consoleErrors.length === 0, consoleErrors.join(' | '));
} finally {
    await browser.close();
}

if (failures.length) {
    console.log(`\n${failures.length} check(s) failed`);
    process.exit(1);
}
