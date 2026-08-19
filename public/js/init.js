/**
 * Early Sidebar Initialization
 * Runs in the <head> before DOM paint to prevent hydration flash (FOUC).
 * Locks HP/XP bars and text at their previous cached state until sidebar.js animates them.
 */
(function () {
    try {
        const lastHpPct = sessionStorage.getItem('mini_last_hp_pct');
        const lastXpPct = sessionStorage.getItem('mini_last_xp_pct');

        const rules = [
            '#sidebar .animate-val, #sidebar .animate-adena { visibility: hidden; }',
            lastHpPct !== null ? `#hp-bar { width: ${lastHpPct}% !important; transition: none !important; }` : '',
            lastXpPct !== null ? `#xp-bar { width: ${lastXpPct}% !important; transition: none !important; }` : ''
        ].filter(Boolean).join(' ');

        const style = document.createElement('style');
        style.id = 'sidebar-init-style';
        style.textContent = rules;
        document.head.appendChild(style);
    } catch (e) {
        // Fallback gracefully if storage is restricted
    }
})();
