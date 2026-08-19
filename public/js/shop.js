/**
 * Shop & Inn Selection Handler
 * Dynamically updates button text and style depending on whether an item is selected or left at 'Return'.
 */
(function () {
    function setupShop(selectId, buttonId, activeText) {
        const sel = document.getElementById(selectId);
        const btn = document.getElementById(buttonId);

        if (sel && btn) {
            sel.addEventListener('change', () => {
                const isDefault = sel.value === '';
                btn.textContent = isDefault ? 'Return' : activeText;
                btn.className = isDefault ? 'btn btn-secondary' : 'btn';
            });
        }
    }

    setupShop('weapon-select', 'weapon-btn', '🪙 Purchase');
    setupShop('armor-select', 'armor-btn', '🪙 Purchase');
    setupShop('inn-select', 'inn-btn', '🪙 Order');
})();
