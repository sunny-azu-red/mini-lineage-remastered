/**
 * Shared Utilities & Global Handlers
 * General-purpose helpers, number formatters, animations, and global page interactions.
 */
const ANIMATION_DURATION_MS = 600;
const TRANSITION_STYLE = `width ${ANIMATION_DURATION_MS}ms cubic-bezier(0.22, 1, 0.36, 1)`;

const formatNumber = (num) => num.toLocaleString(window.CONFIG.locale);
const formatEffectTimer = (remSec) => remSec >= 60 ? `${Math.floor(remSec / 60)}m` : `${Math.max(0, remSec)}`;
const getLowHealthThreshold = (maxHp) => Math.floor(maxHp * window.CONFIG.lowHealthThreshold);
const isLowHealth = (health, maxHp) => health > 0 && health <= getLowHealthThreshold(maxHp);

/**
 * Formats adena amounts with unit abbreviations (k, kk, kkk), floored to one decimal place.
 */
function formatAdena(adena) {
    const abs = Math.abs(adena);
    const sign = adena < 0 ? '-' : '';

    if (abs <= 999)
        return adena.toString();

    const floorToOneDecimal = (divisor, unit) => {
        const calculated = Math.floor((abs / divisor) * 10) / 10;
        return sign + calculated.toFixed(1).replace('.0', '') + unit;
    };

    if (abs < 1_000_000)
        return floorToOneDecimal(1_000, 'k');
    if (abs < 1_000_000_000)
        return floorToOneDecimal(1_000_000, 'kk');

    return floorToOneDecimal(1_000_000_000, 'kkk');
}

/**
 * Animates a numeric element from start to end value using cubic easing.
 * Automatically cancels any existing animation on the element to prevent overlapping jumps.
 */
function animateValue(el, start, end, duration, formatter) {
    if (el.__animId)
        cancelAnimationFrame(el.__animId);

    let startTimestamp = null;
    const fmt = formatter || formatNumber;

    const step = (timestamp) => {
        if (!startTimestamp)
            startTimestamp = timestamp;

        const progress = Math.min((timestamp - startTimestamp) / duration, 1);
        const easeProgress = 1 - Math.pow(1 - progress, 3);

        if (progress < 1) {
            el.innerText = fmt(Math.round(easeProgress * (end - start) + start));
            el.__animId = window.requestAnimationFrame(step);
        } else {
            el.innerText = fmt(end);
            el.__animId = null;
        }
    };

    el.__animId = window.requestAnimationFrame(step);
}

/**
 * Global Page Event Listeners
 */
document.addEventListener('DOMContentLoaded', () => {
    // History back navigation handler
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
     * Global debouncing — prevents rapid double-clicks on buttons and action links.
     * Disables the element immediately and restores it after a safety timeout.
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

            // Defer disabling to the next event loop tick so browser can process navigation/form submission
            setTimeout(() => {
                el.classList.add('btn-disabled');
                if (el instanceof HTMLButtonElement || el instanceof HTMLInputElement)
                    el.disabled = true;
            }, 0);

            // Safety re-enable timeout in case page does not navigate
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
