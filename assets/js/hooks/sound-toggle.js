import { playSound, setSoundEnabled, soundEnabled } from '../soundfx';

/**
 * Mute toggle. The server draws the kept state and both faces' text, so a click only flips between
 * them; the choice is kept for the next page to be served with.
 */
export const SoundToggle = {
    mounted() {
        this.el.addEventListener('click', () => {
            const on = !soundEnabled();
            setSoundEnabled(on);
            this.render(on);
            if (on)
                playSound('toggle');
        });
    },
    render(on) {
        const { on: face, onLabel, off, offLabel } = this.el.dataset;
        const title = on ? onLabel : offLabel;
        this.el.classList.toggle('silenced', !on);
        this.el.title = title;
        this.el.setAttribute('aria-label', title);
        this.el.textContent = on ? face : off;
    },
};
