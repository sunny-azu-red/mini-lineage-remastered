(function () {
    const socket = io();

    // development test: emit a secure ping event
    socket.emit('ping', { timestamp: Date.now() });
    socket.on('pong', (data) => {
        console.log(`[SOCKET] Secure Pong received:`, data);
    });

    // listen for server-pushed player updates (HP, maxHP, effects, stats)
    socket.on('player_update', (data) => {
        if (!data)
            return;

        // update active effects (buffs/debuffs/auras) regardless of HP change
        if (data.effects)
            updateEffects(data.effects);

        // update health bar, value counter, and related UI states
        if (data.health != null)
            updateHealth(data.health, data.maxHealth);

        // update dynamic stats on character page
        if (data.stats)
            updateStats(data.stats);
    });

    /**
     * Updates attack, defense, crit, regen, ambush dynamic stats on the character page.
     */
    function updateStats(stats) {
        const attackEl = document.getElementById('char-stat-attack') || document.getElementById('char-attack');
        if (attackEl)
            attackEl.innerText = Number(stats.attack).toLocaleString();

        const defenseEl = document.getElementById('char-stat-defense') || document.getElementById('char-defense');
        if (defenseEl)
            defenseEl.innerText = Number(stats.defense).toLocaleString();

        const critEl = document.getElementById('char-stat-crit') || document.getElementById('char-crit');
        if (critEl)
            critEl.innerText = Number(stats.crit).toLocaleString();

        const regenEl = document.getElementById('char-stat-regen') || document.getElementById('char-regen');
        if (regenEl)
            regenEl.innerText = Number(stats.regen).toLocaleString();

        const ambushEl = document.getElementById('char-stat-ambush') || document.getElementById('char-ambush');
        if (ambushEl)
            ambushEl.innerText = Number(stats.ambush).toLocaleString();
    }

    /**
     * Efficiently updates the active effects container by comparing incoming IDs
     * with the current ones, ensuring animations only play for new entries.
     */
    function updateEffects(newEffects) {
        const container = document.getElementById('effects');
        if (!container)
            return;

        const currentEffectEls = Array.from(container.querySelectorAll('.effect-icon'));
        const currentKey = currentEffectEls.map(el => el.dataset.effectId + (el.dataset.expiresAt || '')).join(',');
        const newKey = newEffects.map(e => e.id + (e.expiresAt || '')).join(',');

        // skip if nothing changed to avoid flickering or re-triggering animations
        if (currentKey === newKey)
            return;

        const now = Date.now();
        // rebuild the container, but new elements get the fade-in class
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
                timerSpan.innerText = `${remSec}`;
                span.appendChild(timerSpan);
            }

            container.appendChild(span);
        });
    }

    // periodic 1-second interval to update corner timer badges live
    setInterval(() => {
        const timedEffects = document.querySelectorAll('#effects .effect-icon[data-expires-at]');
        if (timedEffects.length === 0)
            return;

        const now = Date.now();
        timedEffects.forEach(el => {
            const expiresAt = Number(el.dataset.expiresAt);
            if (expiresAt) {
                const remMs = expiresAt - now;
                if (remMs <= 0) {
                    el.remove();
                } else {
                    const remSec = Math.ceil(remMs / 1000);
                    const timerEl = el.querySelector('.effect-timer');
                    if (timerEl) {
                        timerEl.innerText = `${remSec}`;
                    }
                }
            }
        });
    }, 1000);

    /**
     * Updates the health bar, value counter, and related UI states (low health warnings).
     */
    function updateHealth(newHp, maxHp) {
        // read the currently displayed HP from the DOM (sidebar or character sheet)
        const hpEl = document.querySelector('#hp-bar ~ .bar-text .animate-val');
        const charHpEl = document.getElementById('char-hp');

        const prevHp = hpEl
            ? (parseInt(hpEl.innerText.replace(/,/g, '')) || newHp)
            : (charHpEl ? (parseInt(charHpEl.innerText.replace(/,/g, '')) || newHp) : newHp);

        // animate the sidebar HP value counter if changed
        if (hpEl && newHp !== prevHp) {
            animateValue(hpEl, prevHp, newHp, 600);
            hpEl.dataset.val = newHp;
            hpEl.dataset.prev = prevHp;
        }

        // animate the character page HP counter if changed
        if (charHpEl && newHp !== prevHp) {
            animateValue(charHpEl, prevHp, newHp, 600);
            charHpEl.dataset.val = newHp;
            charHpEl.dataset.prev = prevHp;
        }

        // update max HP displays and HP bar width
        if (maxHp) {
            const hpBar = document.getElementById('hp-bar');
            if (hpBar) {
                const pct = Math.min(100, Math.round((newHp / maxHp) * 100));
                hpBar.style.width = pct + '%';
            }

            const statusMaxHpEl = document.getElementById('status-max-hp');
            if (statusMaxHpEl)
                statusMaxHpEl.innerText = Number(maxHp).toLocaleString();

            const charMaxHpEl = document.getElementById('char-max-hp');
            if (charMaxHpEl)
                charMaxHpEl.innerText = Number(maxHp).toLocaleString();

            // remove the danger class and low-HP warning if HP is no longer critically low
            if (!isLowHealth(newHp, maxHp)) {
                const barRow = document.querySelector('.stat-row.bar.danger');
                if (barRow)
                    barRow.classList.remove('danger');

                const lowHpAlert = document.getElementById('low-health-alert');
                if (lowHpAlert)
                    lowHpAlert.remove();
            }
        }

        // trigger regen shine animation when HP increases
        if (newHp > prevHp) {
            const hpBar = document.getElementById('hp-bar');
            if (hpBar) {
                hpBar.classList.remove('regen-active');
                void hpBar.offsetWidth; // force reflow to restart the animation
                hpBar.classList.add('regen-active');
                setTimeout(() => hpBar.classList.remove('regen-active'), 500);
            }
        }
    }

    window.gameSocket = socket;
})();
