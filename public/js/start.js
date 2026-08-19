/**
 * Game Start Handler
 * Clears previous character cache from sessionStorage when creating a new character
 * to ensure new character stats start fresh without animating from previous values.
 */
(function () {
    const SIDEBAR_STORAGE_KEYS = [
        'mini_last_hp',
        'mini_last_hp_pct',
        'mini_last_xp',
        'mini_last_xp_pct',
        'mini_last_level',
        'mini_last_adena'
    ];

    const startForm = document.querySelector('form[action="/start"]');
    if (startForm) {
        startForm.addEventListener('submit', () => {
            SIDEBAR_STORAGE_KEYS.forEach(key => sessionStorage.removeItem(key));
        });
    }
})();
