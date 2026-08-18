const formatNumber = (num) => num.toLocaleString(window.CONFIG.locale);
const formatEffectTimer = (remSec) => remSec >= 60 ? `${Math.floor(remSec / 60)}m` : `${Math.max(0, remSec)}`;
const getLowHealthThreshold = (maxHp) => Math.floor(maxHp * window.CONFIG.lowHealthThreshold);
const isLowHealth = (health, maxHp) => health > 0 && health <= getLowHealthThreshold(maxHp);

function animateValue(el, start, end, duration) {
    let startTimestamp = null;
    const step = (timestamp) => {
        if (!startTimestamp) startTimestamp = timestamp;
        const progress = Math.min((timestamp - startTimestamp) / duration, 1);
        const easeProgress = 1 - Math.pow(1 - progress, 3);
        if (progress < 1) {
            el.innerText = formatNumber(Math.round(easeProgress * (end - start) + start));
            window.requestAnimationFrame(step);
        } else {
            el.innerText = formatNumber(end);
        }
    };
    window.requestAnimationFrame(step);
}

/**
 * Global "Go back" handler to safely navigate history without violating CSP.
 * Attach .js-back-link class to any link to enable this behavior.
 */
document.addEventListener('DOMContentLoaded', () => {
    document.querySelectorAll('.js-back-link').forEach(link => {
        link.addEventListener('click', (e) => {
            e.preventDefault();
            if (window.history.length > 1) {
                window.history.back();
            } else {
                window.location.href = '/';
            }
        });
    });

    /**
     * Global debouncing — prevents double-clicks on any actionable element.
     * Targets all <button>, <input[type=submit]>, and <a class="btn"> elements.
     * Disables the element on first click and re-enables after a safety timeout.
     */
    const SAFETY_TIMEOUT_MS = 3000;
    const actionables = document.querySelectorAll('button, input[type="submit"], a.btn');

    actionables.forEach(el => {
        el.addEventListener('click', (e) => {
            if (el.classList.contains('btn-disabled')) {
                e.preventDefault();
                e.stopImmediatePropagation();
                return;
            }

            // defer disabling to the next tick so the browser can process the current click (e.g. form submission, link navigation)
            setTimeout(() => {
                el.classList.add('btn-disabled');
                if (el instanceof HTMLButtonElement || el instanceof HTMLInputElement)
                    el.disabled = true;
            }, 0);

            // safety re-enable in case the page doesn't navigate (e.g. error, SPA)
            setTimeout(() => {
                el.classList.remove('btn-disabled');
                if (el instanceof HTMLButtonElement || el instanceof HTMLInputElement)
                    el.disabled = false;
            }, SAFETY_TIMEOUT_MS);
        });
    });

    /**
     * Input dispatcher for hotkeys and control interactions.
     */
    window.addEventListener('keydown', (e) => {
        if (!e.key || e.repeat || e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement)
            return;

        if (window.gameSocket) {
            window.gameSocket.emit('input', { key: e.key.toLowerCase() });
        }
    });
});
