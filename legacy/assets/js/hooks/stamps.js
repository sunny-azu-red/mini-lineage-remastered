/**
 * When something happened, aged on the reader's clock and dated in their zone. Twinned with
 * `Format.stamp/5` and `Format.stamp_title/1`; both are held to test/fixtures/stamp_format.json.
 */
const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const FULL_MONTHS = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August',
    'September', 'October', 'November', 'December'];

// `utc` is for the table, whose dates are UTC; the page leaves it off and gets the reader's zone.
function parts(ms, utc) {
    const d = new Date(ms);
    return utc
        ? { year: d.getUTCFullYear(), month: d.getUTCMonth(), day: d.getUTCDate(), hour: d.getUTCHours(), minute: d.getUTCMinutes() }
        : { year: d.getFullYear(), month: d.getMonth(), day: d.getDate(), hour: d.getHours(), minute: d.getMinutes() };
}

const pad = (n) => String(n).padStart(2, '0');
const dayOf = (p, form = 'short') => `${p.day} ${(form === 'long' ? FULL_MONTHS : MONTHS)[p.month]}`;
// Twelve-hour, and the game's own rather than the browser's locale, so the two sides agree.
const clockOf = (p) => `${p.hour % 12 || 12}:${pad(p.minute)} ${p.hour < 12 ? 'am' : 'pm'}`;

function ago(n, unit, word, form) {
    if (form === 'short') return `${n}${unit} ago`;
    if (n === 1) return word === 'hour' ? 'an hour ago' : `a ${word} ago`;
    return `${n} ${word}s ago`;
}

// `opts` shape only a date: `on`, `time`, and `atTime` for "at 9:05 am" rather than ", 9:05 am".
export function stampLabel(atMs, nowMs, capMs, form, opts = {}, utc = false) {
    const age = nowMs - atMs;

    if (age >= capMs) {
        const at = parts(atMs, utc);
        const year = at.year === parts(nowMs, utc).year ? '' : ` ${at.year}`;
        const time = !opts.time ? '' : `${opts.atTime ? ' at' : ','} ${clockOf(at)}`;
        return `${opts.on ? 'on ' : ''}${dayOf(at, form)}${year}${time}`;
    }
    if (age < 60_000) return 'just now';
    if (age < 3_600_000) return ago(Math.floor(age / 60_000), 'm', 'minute', form);
    if (age < 86_400_000) return ago(Math.floor(age / 3_600_000), 'h', 'hour', form);
    return ago(Math.floor(age / 86_400_000), 'd', 'day', form);
}

export function stampTitle(atMs, utc = false) {
    const at = parts(atMs, utc);
    return `${dayOf(at)} ${at.year}, ${clockOf(at)}`;
}

// One clock for every container on the page, and only while some stamp is still an age: past the
// cap a label never changes again, so a page of old dates does not tick at all.
const live = new Set();
let ticker = null;

function tick() {
    let aging = false;
    for (const hook of live) aging = hook.paint() || aging;
    if (!aging) ticker = clearInterval(ticker);
}

// A background tab's timers are throttled, so it is caught up the moment it is looked at again.
document.addEventListener('visibilitychange', () => document.hidden || tick());

export const Stamps = {
    mounted() {
        // Read once: the server's clock as this was drawn, so a wrong clock here ages from its frame.
        this.skew = Number(this.el.dataset.now) - Date.now() || 0;
        live.add(this);
        this.render();
    },
    updated() {
        this.render();
    },
    destroyed() {
        live.delete(this);
        if (!live.size) ticker = clearInterval(ticker);
    },
    render() {
        if (this.paint() && !ticker) ticker = setInterval(tick, 15_000);
    },
    // Writes only what changed, so a tick that moves no label touches no node.
    paint() {
        const now = Date.now() + this.skew, cap = Number(this.el.dataset.capMs);
        let aging = false;

        for (const el of this.el.querySelectorAll('time[datetime]')) {
            const at = Date.parse(el.dateTime);
            if (isNaN(at)) continue;

            const label = stampLabel(at, now, cap, el.dataset.form, {
                on: el.hasAttribute('data-on'),
                time: el.hasAttribute('data-time'),
                atTime: el.hasAttribute('data-at-time'),
            });
            if (el.textContent !== label) el.textContent = label;
            const title = stampTitle(at);
            if (el.title !== title) el.title = title;
            aging ||= now - at < cap;
        }
        return aging;
    },
};
