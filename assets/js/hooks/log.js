// How far inside the box a jump leaves the line, so its count clears the edge.
const LINE_MARGIN = 24;

/**
 * A panel that is a log, newest first or oldest first; the rules are AGENTS.md's. The line and the
 * pill are re-applied after every patch, which rewrites both, and the server is told only whether
 * the reader is at the present.
 */
export class Log {
    constructor(panel) {
        this.panel = panel;
        this.el = panel.el;
        this.bottom = this.el.dataset.log === 'oldest-first';
        this.pill = this.el.querySelector(':scope > .panel-unread');
        this.body().addEventListener('scroll', () => this.scrolled(), { passive: true });
        this.pill?.addEventListener('click', () => this.jump());
        // A hidden tab is away too: what lands in it is shown once the reader is back to see it.
        this.onVisible = () => this.look();
        document.addEventListener('visibilitychange', this.onVisible);
        this.start();
    }
    destroy() {
        document.removeEventListener('visibilitychange', this.onVisible);
    }
    start() {
        this.pinned = true;
        // What the server was last told; it assumes the present, where a log opens.
        this.told = true;
        // The entry the line is drawn under, and how many arrived above it (below it, in a chat).
        this.edge = null;
        this.unseen = new Set();
        // Whether the line has been in view, after which the pill counts what is left.
        this.reached = false;
        this.newest = this.entries()[0]?.id;
        this.toPresent();
        this.showed();
    }
    body() {
        return this.el.querySelector(':scope > .panel-body');
    }
    list() {
        return this.body().firstElementChild;
    }
    // Newest first, whichever way the list is written.
    entries() {
        const items = [...(this.list()?.children ?? [])];
        return this.bottom ? items.reverse() : items;
    }
    atPresent() {
        const body = this.body();
        return this.bottom ? body.scrollHeight - body.clientHeight - body.scrollTop <= 2 : body.scrollTop <= 2;
    }
    toPresent() {
        const body = this.body();
        body.scrollTop = this.bottom ? body.scrollHeight : 0;
    }
    // The panel has just been shown or re-shown. A chat's reader at its present is kept there.
    showed() {
        if (this.bottom && this.pinned) this.toPresent();
        this.paint();
        this.fill();
    }
    // A hidden tab is kept where it was too, so its reader comes back to the view they left.
    beforeUpdate() {
        this.anchor = this.panel.shown() && this.away() ? this.place() : null;
    }
    updated() {
        const away = this.away();
        this.keepPlace();
        if (this.bottom && !away) this.toPresent();
        // Asked now rather than left to the scroll event, which a hidden tab only delivers once shown.
        this.pinned = this.atPresent();
        this.arrived(away);
        this.look();
        this.report();
    }
    // What landed on the present side of the newest entry held before the patch.
    arrived(away) {
        const entries = this.entries();
        const was = this.newest;
        const at = entries.findIndex(li => li.id === was);
        this.newest = entries[0]?.id;
        if (at <= 0 || !this.panel.shown()) return;

        const fresh = entries.slice(0, at);
        if (!away) {
            // Watched as it lands: a line from an absence already read through says nothing now.
            if (!this.unseen.size) this.edge = null;
            return;
        }
        // A new absence draws a new line; one the reader has not caught up on grows instead.
        if (!this.edge || !this.unseen.size) {
            this.edge = { id: this.bottom ? was : fresh.at(-1).id, count: 0 };
            this.reached = false;
        }
        this.edge.count += fresh.length;
        for (const li of fresh) this.unseen.add(li.id);
    }
    away() {
        return !this.pinned || document.hidden;
    }
    // The line's height on screen: the past side of its entry, which is its bottom in either order.
    line() {
        return (this.edge && document.getElementById(this.edge.id)?.getBoundingClientRect().bottom) ?? null;
    }
    // Where the line stands against the box: ahead of the reader, towards the present, in view, or
    // behind them. On the box's very edge, where a hidden tab leaves it, it is not yet in view.
    lineAt(box) {
        const line = this.line();
        if (line === null) return null;
        const [top, bottom] = [line <= box.top + 2, line >= box.bottom - 2];
        if (this.bottom ? bottom : top) return 'ahead';
        return (this.bottom ? top : bottom) ? 'behind' : 'in';
    }
    // Whatever is on screen has been read, and the present is caught up. A line goes once it has been
    // reached and read past, never while somebody could still be scrolling towards it.
    look() {
        if (this.edge && this.panel.shown() && !document.hidden) {
            if (this.pinned) this.unseen.clear();
            const box = this.body().getBoundingClientRect();
            for (const id of this.unseen) {
                const at = document.getElementById(id)?.getBoundingClientRect();
                const inView = at && Math.min(at.bottom, box.bottom) - Math.max(at.top, box.top);
                if (!at || inView >= Math.min(at.height, box.height) / 2) this.unseen.delete(id);
            }
            const at = this.lineAt(box);
            if (at === 'in') this.reached = true;
            else if (at === null || (this.reached && !this.unseen.size)) {
                this.edge = null;
                this.unseen.clear();
            }
        }
        this.paint();
    }
    scrolled() {
        const body = this.body();
        this.pinned = this.atPresent();
        this.look();
        // A box's height from the past edge, so the page is usually in before the reader reaches it.
        const left = this.bottom ? body.scrollTop : body.scrollHeight - body.clientHeight - body.scrollTop;
        if (left < body.clientHeight) this.loadOlder();
        this.report();
    }
    // To where the reader left off, with the line on the box's past edge; from there, or with the
    // line in view or behind them, to the present.
    jump() {
        const body = this.body();
        const box = body.getBoundingClientRect();
        const line = this.line();

        if (this.lineAt(box) === 'ahead')
            body.scrollTop += line - (this.bottom ? box.top + LINE_MARGIN : box.bottom - LINE_MARGIN);
        else this.toPresent();
        this.scrolled();
    }
    paint() {
        for (const li of this.list()?.querySelectorAll(':scope > [data-unread]') ?? [])
            if (li.id !== this.edge?.id) li.removeAttribute('data-unread');
        if (this.edge) document.getElementById(this.edge.id)?.setAttribute('data-unread', this.edge.count);

        if (!this.pill) return;
        const count = this.unseen.size;
        const { one, many, rest } = this.pill.dataset;
        this.pill.hidden = !(this.panel.shown() && count);
        this.pill.lastElementChild.textContent = `${count} ${this.reached ? rest : count === 1 ? one : many}`;
    }
    // A box its entries do not fill cannot be scrolled to ask for the next page, so it asks now.
    fill() {
        const body = this.body();
        if (this.panel.shown() && body.scrollHeight <= body.clientHeight) this.loadOlder();
    }
    // The entry at the top of the box and where it sits, so an entry arriving above it, a page put in
    // front of it, or a push that briefly re-renders the header leaves the reader on the same line.
    place() {
        const body = this.body();
        const top = body.getBoundingClientRect().top;
        // From inside the box's border, or the row whose last pixel sits under it is the one held.
        const entry = [...(this.list()?.children ?? [])]
            .find(li => li.getBoundingClientRect().bottom > top + body.clientTop);

        return entry && { id: entry.id, offset: entry.getBoundingClientRect().top - top };
    }
    keepPlace() {
        const entry = this.anchor && document.getElementById(this.anchor.id);
        if (!entry || !this.panel.shown()) return;

        const body = this.body();
        body.scrollTop += entry.getBoundingClientRect().top - body.getBoundingClientRect().top - this.anchor.offset;
    }
    // Only as it changes: a reader following a fight at the present sends nothing per arrival.
    report() {
        const event = this.el.dataset.atPresent;
        if (!event || this.pinned === this.told) return;

        this.told = this.pinned;
        this.panel.pushEvent(event, { at: this.pinned });
    }
    loadOlder() {
        const before = this.list()?.dataset.olderThan;
        const event = this.el.dataset.loadOlder;
        if (!before || !event || this.loading) return;

        this.loading = true;
        this.panel.pushEvent(event, { before: Number(before) }, () => { this.loading = false; });
    }
}
