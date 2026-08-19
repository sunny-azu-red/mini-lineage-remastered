/**
 * Home Menu Navigation Handler
 * Updates travel button text dynamically and handles destination navigation on form submit.
 */
(function () {
    const sel = document.getElementById('home-select');
    const btn = document.getElementById('home-btn');
    const form = document.getElementById('home-form');

    if (sel && btn) {
        sel.addEventListener('change', () => {
            btn.textContent = sel.value === '/suicide' ? '⚰️ Perish' : 'Travel';
        });

        if (form) {
            form.addEventListener('submit', (e) => {
                e.preventDefault();
                window.location.href = sel.value;
            });
        }
    }
})();
