/**
 * Suicide Confirmation Handler
 * Dynamically updates the action button style and text based on user selection.
 */
(function () {
    const sel = document.getElementById('suicide-select');
    const btn = document.getElementById('suicide-btn');

    if (sel && btn) {
        sel.addEventListener('change', () => {
            if (sel.value === 'yes') {
                btn.textContent = 'Do it 🥀';
                btn.className = 'btn btn-danger';
            } else {
                btn.textContent = 'Phew 😅';
                btn.className = 'btn btn-secondary';
            }
        });
    }
})();
