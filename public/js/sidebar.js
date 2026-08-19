/**
 * Sidebar Stats & Progress Animation Handler
 * Compares current target stats against cached values in sessionStorage.
 * Smoothly interpolates HP, XP, and Adena changes using CSS transitions and requestAnimationFrame.
 */
(function () {
    const hpBar = document.getElementById('hp-bar');
    const xpBar = document.getElementById('xp-bar');
    const hpValEl = document.querySelector('#hp-bar ~ .bar-text .animate-val');
    const xpValEl = document.querySelector('#xp-bar ~ .bar-text .animate-val');
    const adenaValEl = document.querySelector('.animate-adena');

    if (!hpBar || !hpValEl)
        return;

    // Current page target values
    const targetHp = parseInt(hpValEl.dataset.val, 10) || 0;
    const targetHpPct = parseFloat(hpBar.dataset.pct) || 0;
    const targetXp = xpValEl ? (parseInt(xpValEl.dataset.val, 10) || 0) : 0;
    const targetXpPct = xpBar ? (parseFloat(xpBar.dataset.pct) || 0) : 0;
    const targetLevel = xpBar ? (parseInt(xpBar.dataset.level, 10) || 0) : 0;
    const targetAdena = adenaValEl ? (parseInt(adenaValEl.dataset.val, 10) || 0) : 0;

    // Previous cached values from sessionStorage
    const lastHpStr = sessionStorage.getItem('mini_last_hp');
    const lastHpPctStr = sessionStorage.getItem('mini_last_hp_pct');
    const lastXpStr = sessionStorage.getItem('mini_last_xp');
    const lastXpPctStr = sessionStorage.getItem('mini_last_xp_pct');
    const lastLevelStr = sessionStorage.getItem('mini_last_level');
    const lastAdenaStr = sessionStorage.getItem('mini_last_adena');

    // 1. Health Bar Animation Setup
    let shouldAnimateHp = false;
    let startHp = targetHp;
    let startHpPct = targetHpPct;

    if (lastHpStr !== null && lastHpPctStr !== null) {
        const lastHp = parseInt(lastHpStr, 10);
        const lastHpPct = parseFloat(lastHpPctStr);
        if (!isNaN(lastHp) && lastHp !== targetHp) {
            shouldAnimateHp = true;
            startHp = lastHp;
            startHpPct = lastHpPct;
            hpBar.style.transition = 'none';
            hpBar.style.width = `${startHpPct}%`;
            hpValEl.innerText = startHp.toLocaleString();
        }
    }

    // 2. Experience Bar Animation Setup (handles level-up resets)
    let shouldAnimateXp = false;
    let startXp = targetXp;
    let startXpPct = targetXpPct;

    if (xpBar && xpValEl && lastXpStr !== null && lastXpPctStr !== null) {
        const lastXp = parseInt(lastXpStr, 10);
        const lastXpPct = parseFloat(lastXpPctStr);
        const lastLevel = parseInt(lastLevelStr, 10) || 0;
        const isLevelUp = lastLevel > 0 && targetLevel > lastLevel;

        if (!isNaN(lastXp) && lastXp !== targetXp) {
            shouldAnimateXp = true;
            startXp = isLevelUp ? 0 : lastXp;
            startXpPct = isLevelUp ? 0 : lastXpPct;
            xpBar.style.transition = 'none';
            xpBar.style.width = `${startXpPct}%`;
            xpValEl.innerText = startXp.toLocaleString();
        }
    }

    // 3. Adena Counter Animation Setup
    let shouldAnimateAdena = false;
    let startAdena = targetAdena;

    if (adenaValEl && lastAdenaStr !== null) {
        const lastAdena = parseInt(lastAdenaStr, 10);
        if (!isNaN(lastAdena) && lastAdena !== targetAdena) {
            shouldAnimateAdena = true;
            startAdena = lastAdena;
            adenaValEl.innerText = typeof formatAdena === 'function' ? formatAdena(startAdena) : startAdena.toLocaleString();
        }
    }

    // Immediately cache target values for the next page load
    sessionStorage.setItem('mini_last_hp', targetHp);
    sessionStorage.setItem('mini_last_hp_pct', targetHpPct);
    if (xpValEl)
        sessionStorage.setItem('mini_last_xp', targetXp);
    if (xpBar) {
        sessionStorage.setItem('mini_last_xp_pct', targetXpPct);
        sessionStorage.setItem('mini_last_level', targetLevel);
    }
    if (adenaValEl)
        sessionStorage.setItem('mini_last_adena', targetAdena);

    // Remove the temporary early-init style block so CSS transitions can take over
    const initStyle = document.getElementById('sidebar-init-style');
    if (initStyle)
        initStyle.remove();

    // Trigger animations in double rAF to ensure starting state renders before transition
    if (shouldAnimateHp || shouldAnimateXp || shouldAnimateAdena) {
        requestAnimationFrame(() => {
            requestAnimationFrame(() => {
                if (shouldAnimateHp) {
                    hpBar.style.transition = TRANSITION_STYLE;
                    hpBar.style.width = `${targetHpPct}%`;
                    animateValue(hpValEl, startHp, targetHp, ANIMATION_DURATION_MS);
                }
                if (shouldAnimateXp && xpBar) {
                    xpBar.style.transition = TRANSITION_STYLE;
                    xpBar.style.width = `${targetXpPct}%`;
                    animateValue(xpValEl, startXp, targetXp, ANIMATION_DURATION_MS);
                }
                if (shouldAnimateAdena && adenaValEl)
                    animateValue(adenaValEl, startAdena, targetAdena, ANIMATION_DURATION_MS, typeof formatAdena === 'function' ? formatAdena : undefined);
            });
        });
    }
})();
