(function () {
    const socket = io();

    // development test: emit a secure ping event
    socket.emit('ping', { timestamp: Date.now() });
    socket.on('pong', (data) => {
        console.log(`[SOCKET] Secure Pong received:`, data);
    });

    // listen for server-pushed HP updates (regen ticks, future buff/debuff ticks)
    socket.on('player_update', (data) => {
        if (!data)
            return;

        // update auras (buffs/debuffs) regardless of HP change
        if (data.auras)
            updateAuras(data.auras);

        // update health bar, value counter, and related UI states (low health warnings)
        if (data.health != null)
            updateHealth(data.health, data.maxHealth);
    });

    /**
     * Efficiently updates the auras container by comparing incoming IDs
     * with the current ones, ensuring animations only play for new entries.
     */
    function updateAuras(newAuras) {
        const container = document.getElementById('auras');
        if (!container)
            return;

        const currentAuraEls = Array.from(container.querySelectorAll('.header-stats-value'));
        const currentKey = currentAuraEls.map(el => el.dataset.auraId + el.innerText).join(',');
        const newKey = newAuras.map(a => a.id + a.icon).join(',');

        // skip if nothing changed to avoid flickering or re-triggering animations
        if (currentKey === newKey)
            return;

        // rebuild the container, but new elements get the fade-in class
        container.innerHTML = '';
        newAuras.forEach(aura => {
            const span = document.createElement('span');
            span.className = 'header-stats-value aura-fade-in';
            span.dataset.auraId = aura.id;
            span.title = aura.label;
            span.innerText = aura.icon;
            container.appendChild(span);
        });
    }

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

        // skip if the HP hasn't actually changed (e.g. initial sync matches server-rendered HTML)
        if (newHp === prevHp)
            return;

        // animate the sidebar HP value counter
        if (hpEl) {
            animateValue(hpEl, prevHp, newHp, 600);
            hpEl.dataset.val = newHp;
            hpEl.dataset.prev = prevHp;
        }

        // animate the character page HP counter
        if (charHpEl) {
            animateValue(charHpEl, prevHp, newHp, 600);
            charHpEl.dataset.val = newHp;
            charHpEl.dataset.prev = prevHp;
        }

        // animate the HP bar width
        if (maxHp) {
            const hpBar = document.getElementById('hp-bar');
            if (hpBar) {
                const pct = Math.min(100, Math.round((newHp / maxHp) * 100));
                hpBar.style.width = pct + '%';
            }

            // remove the danger class and low-HP warning if HP is no longer critically low
            if (maxHp && !isLowHealth(newHp, maxHp)) {
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
})();
