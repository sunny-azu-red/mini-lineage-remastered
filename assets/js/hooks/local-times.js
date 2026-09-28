/**
 * Rewrites a server-rendered UTC stamp into the reader's own clock — the browser is the only thing
 * that knows it. Same shape as `Controls.short_date/1`, which stays as the no-JS fallback.
 */
function localDate(at) {
    const pad = (n) => String(n).padStart(2, '0');

    return `${pad(at.getDate())}/${pad(at.getMonth() + 1)}/${String(at.getFullYear()).slice(-2)}, `
        + `${pad(at.getHours())}:${pad(at.getMinutes())}`;
}

// One hook over whatever holds stamps, rewriting every one beneath it to the reader's clock: a
// hook per stamp would be fifty for one job on a chronicle, and twenty-five on the Halls.
export const LocalTimes = {
    mounted() {
        this.render();
    },
    updated() {
        this.render();
    },
    render() {
        for (const el of this.el.querySelectorAll('time[datetime]')) {
            const at = new Date(el.dateTime);

            if (!isNaN(at)) el.textContent = localDate(at);
        }
    },
};
