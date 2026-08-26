/**
 * Real-Time Socket Connection & State Synchronization
 * Listens for server-pushed player updates (HP, stats, active buffs/debuffs/auras)
 * and animates UI components in real time without requiring page reloads.
 */
(function () {
    const socket = io();

    /**
     * Server Player State Dispatcher
     */
    socket.on('player_update', (data) => {
        if (!data)
            return;

        if (data.effects)
            updateEffects(data.effects);

        if (data.health != null)
            updateHealth(data.health, data.maxHealth);

        if (data.stats)
            updateStats(data.stats);
    });

    /**
     * Updates dynamic combat and character statistics on the Character view.
     */
    function updateStats(stats) {
        const statMappings = [
            { el: document.getElementById('char-stat-attack') || document.getElementById('char-attack'), val: stats.attack },
            { el: document.getElementById('char-stat-defense') || document.getElementById('char-defense'), val: stats.defense },
            { el: document.getElementById('char-stat-crit') || document.getElementById('char-crit'), val: stats.crit },
            { el: document.getElementById('char-stat-regen') || document.getElementById('char-regen'), val: stats.regen },
            { el: document.getElementById('char-stat-ambush') || document.getElementById('char-ambush'), val: stats.ambush },
        ];

        statMappings.forEach(({ el, val }) => {
            if (el && val != null)
                el.innerText = Number(val).toLocaleString();
        });
    }

    /**
     * Updates header status effect badges, tooltips, and countdown timers.
     */
    function updateEffects(newEffects) {
        const container = document.getElementById('effects');
        if (!container)
            return;

        const currentEffectEls = Array.from(container.querySelectorAll('.effect-icon'));
        const currentKey = currentEffectEls.map(el => el.dataset.effectId + (el.dataset.expiresAt || '')).join(',');
        const newKey = newEffects.map(e => e.id + (e.expiresAt || '')).join(',');

        // Skip DOM rebuild if active effects have not changed
        if (currentKey === newKey)
            return;

        const now = Date.now();
        container.innerHTML = '';

        newEffects.forEach(effect => {
            const span = document.createElement('span');
            const typeClass = effect.type ? ` effect-${effect.type}` : '';
            span.className = `effect-icon effect-fade-in${typeClass}`;
            span.dataset.effectId = effect.id;
            span.dataset.label = effect.label;
            span.title = effect.tooltip || effect.label;

            const emojiSpan = document.createElement('span');
            emojiSpan.className = 'effect-emoji';
            emojiSpan.innerText = effect.emoji;
            span.appendChild(emojiSpan);

            if (effect.expiresAt) {
                span.dataset.expiresAt = effect.expiresAt;
                const remSec = Math.max(0, Math.ceil((effect.expiresAt - now) / 1000));
                const timerSpan = document.createElement('span');
                timerSpan.className = 'effect-timer';
                timerSpan.innerText = formatEffectTimer(remSec);
                span.appendChild(timerSpan);
            }

            container.appendChild(span);
        });
    }

    /**
     * Periodic live countdown for expiring status effect badges.
     */
    setInterval(() => {
        const timedEffects = document.querySelectorAll('#effects .effect-icon[data-expires-at]');
        if (timedEffects.length === 0)
            return;

        const now = Date.now();
        timedEffects.forEach(el => {
            const expiresAt = Number(el.dataset.expiresAt);
            if (expiresAt) {
                const remMs = expiresAt - now;
                if (remMs <= 0)
                    el.remove();
                else {
                    const remSec = Math.ceil(remMs / 1000);
                    const timerEl = el.querySelector('.effect-timer');
                    if (timerEl)
                        timerEl.innerText = formatEffectTimer(remSec);
                }
            }
        });
    }, 1000);

    /**
     * Updates HP bars, numeric counters, and low-health UI warnings in real time.
     */
    function updateHealth(newHp, maxHp) {
        const hpEl = document.querySelector('#hp-bar ~ .bar-text .animate-val');
        const charHpEl = document.getElementById('char-hp');

        const prevHp = hpEl
            ? (parseInt(hpEl.innerText.replace(/,/g, ''), 10) || newHp)
            : (charHpEl ? (parseInt(charHpEl.innerText.replace(/,/g, ''), 10) || newHp) : newHp);

        // Animate HP numeric counters if value changed
        if (hpEl && newHp !== prevHp) {
            animateValue(hpEl, prevHp, newHp, ANIMATION_DURATION_MS);
            hpEl.dataset.val = newHp;
            hpEl.dataset.prev = prevHp;
        }

        if (charHpEl && newHp !== prevHp) {
            animateValue(charHpEl, prevHp, newHp, ANIMATION_DURATION_MS);
            charHpEl.dataset.val = newHp;
            charHpEl.dataset.prev = prevHp;
        }

        // Update HP progress bar width and max HP displays
        if (maxHp) {
            const pct = Math.min(100, Math.round((newHp / maxHp) * 100));
            sessionStorage.setItem('mini_last_hp', newHp);
            sessionStorage.setItem('mini_last_hp_pct', pct);

            const hpBar = document.getElementById('hp-bar');
            if (hpBar) {
                hpBar.style.transition = TRANSITION_STYLE;
                hpBar.style.width = `${pct}%`;
            }

            const statusMaxHpEl = document.getElementById('status-max-hp');
            if (statusMaxHpEl)
                statusMaxHpEl.innerText = Number(maxHp).toLocaleString();

            const charMaxHpEl = document.getElementById('char-max-hp');
            if (charMaxHpEl)
                charMaxHpEl.innerText = Number(maxHp).toLocaleString();

            // Clear danger classes and alerts if HP recovered above threshold
            if (!isLowHealth(newHp, maxHp)) {
                const barRow = document.querySelector('.stat-row.bar.danger');
                if (barRow)
                    barRow.classList.remove('danger');

                const lowHpAlert = document.getElementById('low-health-alert');
                if (lowHpAlert)
                    lowHpAlert.remove();
            }
        }

        // Trigger HP regen shine animation when recovering health
        if (newHp > prevHp) {
            const hpBar = document.getElementById('hp-bar');
            if (hpBar) {
                hpBar.classList.remove('shimmer-active');
                void hpBar.offsetWidth; // Force reflow to restart CSS animation
                hpBar.classList.add('shimmer-active');
                setTimeout(() => hpBar.classList.remove('shimmer-active'), ANIMATION_DURATION_MS);
            }
        }
    }

    window.gameSocket = socket;
})();
