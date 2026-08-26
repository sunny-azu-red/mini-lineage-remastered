/**
 * 8-Bit Retro Web Audio Synthesizer Engine
 * Pure procedural sound effects with zero external audio assets.
 */
(function () {
    const STORAGE_KEY = 'mini_sound_enabled';
    let audioCtx = null;

    // Default to true if not set
    let isSoundEnabled = localStorage.getItem(STORAGE_KEY) !== 'false';

    /**
     * Lazily initializes and unlocks the Web Audio AudioContext.
     */
    function getAudioContext() {
        if (!audioCtx) {
            const AudioContextClass = window.AudioContext || window.webkitAudioContext;
            if (AudioContextClass)
                audioCtx = new AudioContextClass();
        }

        if (audioCtx && audioCtx.state === 'suspended')
            audioCtx.resume();

        return audioCtx;
    }

    // Auto-resume AudioContext on first user interaction in compliance with browser autoplay policy
    function unlockAudio() {
        getAudioContext();
        window.removeEventListener('pointerdown', unlockAudio);
        window.removeEventListener('keydown', unlockAudio);
    }
    window.addEventListener('pointerdown', unlockAudio);
    window.addEventListener('keydown', unlockAudio);

    /**
     * Executes synthesizer logic if sound is enabled and AudioContext is available.
     */
    function play(synthFn) {
        if (!isSoundEnabled)
            return;

        const ctx = getAudioContext();
        if (!ctx)
            return;

        synthFn(ctx, ctx.currentTime);
    }

    const SoundFX = {
        /**
         * Checks if sound effects are enabled.
         */
        isEnabled() {
            return isSoundEnabled;
        },

        /**
         * Toggles sound on/off and updates localStorage + UI.
         */
        toggle() {
            isSoundEnabled = !isSoundEnabled;
            localStorage.setItem(STORAGE_KEY, isSoundEnabled ? 'true' : 'false');
            this.updateToggleUI();

            if (isSoundEnabled)
                this.buy(); // Short feedback chime when un-muting

            return isSoundEnabled;
        },

        /**
         * Updates the sound toggle button icon in the UI.
         */
        updateToggleUI() {
            const btn = document.getElementById('sound-toggle');
            if (btn) {
                btn.innerText = isSoundEnabled ? '🔊' : '🔇';
                btn.title = isSoundEnabled ? 'Sound FX Enabled (Click to Mute)' : 'Sound FX Muted (Click to Unmute)';
                btn.setAttribute('aria-label', btn.title);
                btn.classList.toggle('muted', !isSoundEnabled);
            }
        },

        /**
         * ⚔️ Critical Hit - Punchy 8-bit impact crunch with rapid pitch slide.
         */
        crit() {
            play((ctx, now) => {
                const osc = ctx.createOscillator();
                const gain = ctx.createGain();
                osc.type = 'sawtooth';

                osc.frequency.setValueAtTime(420, now);
                osc.frequency.exponentialRampToValueAtTime(60, now + 0.13);

                gain.gain.setValueAtTime(0.18, now);
                gain.gain.exponentialRampToValueAtTime(0.001, now + 0.15);

                osc.connect(gain);
                gain.connect(ctx.destination);

                osc.start(now);
                osc.stop(now + 0.16);
            });
        },

        /**
         * 🍖 Eat / Food Heal - Ascending triple chime (vitality restore).
         */
        eat() {
            play((ctx, now) => {
                const notes = [330, 440, 660]; // E4, A4, E5
                notes.forEach((freq, idx) => {
                    const osc = ctx.createOscillator();
                    const gain = ctx.createGain();
                    osc.type = 'triangle';
                    const startTime = now + idx * 0.06;
                    const duration = 0.12;

                    osc.frequency.setValueAtTime(freq, startTime);
                    gain.gain.setValueAtTime(0.14, startTime);
                    gain.gain.exponentialRampToValueAtTime(0.001, startTime + duration);

                    osc.connect(gain);
                    gain.connect(ctx.destination);

                    osc.start(startTime);
                    osc.stop(startTime + duration + 0.01);
                });
            });
        },

        /**
         * ✨ Level Up - Triumphant 4-note retro fanfare (C5 -> E5 -> G5 -> C6).
         */
        level() {
            play((ctx, now) => {
                const notes = [523.25, 659.25, 783.99, 1046.50]; // C5, E5, G5, C6
                notes.forEach((freq, idx) => {
                    const osc = ctx.createOscillator();
                    const gain = ctx.createGain();
                    osc.type = 'square';
                    const startTime = now + idx * 0.09;
                    const duration = idx === notes.length - 1 ? 0.38 : 0.08;

                    osc.frequency.setValueAtTime(freq, startTime);
                    gain.gain.setValueAtTime(0.12, startTime);
                    gain.gain.exponentialRampToValueAtTime(0.001, startTime + duration);

                    osc.connect(gain);
                    gain.connect(ctx.destination);

                    osc.start(startTime);
                    osc.stop(startTime + duration + 0.02);
                });
            });
        },

        /**
         * 💀 Death - Slow melancholic downward game over slide.
         */
        death() {
            play((ctx, now) => {
                const osc = ctx.createOscillator();
                const gain = ctx.createGain();
                osc.type = 'sawtooth';

                osc.frequency.setValueAtTime(260, now);
                osc.frequency.linearRampToValueAtTime(180, now + 0.18);
                osc.frequency.linearRampToValueAtTime(120, now + 0.36);
                osc.frequency.exponentialRampToValueAtTime(45, now + 0.68);

                gain.gain.setValueAtTime(0.16, now);
                gain.gain.exponentialRampToValueAtTime(0.001, now + 0.70);

                osc.connect(gain);
                gain.connect(ctx.destination);

                osc.start(now);
                osc.stop(now + 0.72);
            });
        },

        /**
         * 🪙 Purchase / Shop - Crisp double chime coin exchange.
         */
        buy() {
            play((ctx, now) => {
                const notes = [987.77, 1318.51]; // B5, E6
                notes.forEach((freq, idx) => {
                    const osc = ctx.createOscillator();
                    const gain = ctx.createGain();
                    osc.type = 'sine';
                    const startTime = now + idx * 0.07;
                    const duration = 0.09;

                    osc.frequency.setValueAtTime(freq, startTime);
                    gain.gain.setValueAtTime(0.13, startTime);
                    gain.gain.exponentialRampToValueAtTime(0.001, startTime + duration);

                    osc.connect(gain);
                    gain.connect(ctx.destination);

                    osc.start(startTime);
                    osc.stop(startTime + duration + 0.01);
                });
            });
        },

        /**
         * 🌟 Game Start - Heroic awakening fanfare (D4 -> F#4 -> A4 -> D5).
         */
        start() {
            play((ctx, now) => {
                const notes = [
                    { freq: 293.66, type: 'triangle', dur: 0.12 }, // D4
                    { freq: 369.99, type: 'triangle', dur: 0.12 }, // F#4
                    { freq: 440.00, type: 'triangle', dur: 0.14 }, // A4
                    { freq: 587.33, type: 'square', dur: 0.45 }, // D5
                ];

                notes.forEach((note, idx) => {
                    const osc = ctx.createOscillator();
                    const gain = ctx.createGain();
                    osc.type = note.type;
                    const startTime = now + idx * 0.10;

                    osc.frequency.setValueAtTime(note.freq, startTime);
                    gain.gain.setValueAtTime(0.14, startTime);
                    gain.gain.exponentialRampToValueAtTime(0.001, startTime + note.dur);

                    osc.connect(gain);
                    gain.connect(ctx.destination);

                    osc.start(startTime);
                    osc.stop(startTime + note.dur + 0.02);
                });
            });
        },

        /**
         * 💢 Ambush - Urgent dissonant retro alarm pulses.
         */
        ambush() {
            play((ctx, now) => {
                [0, 0.11, 0.22].forEach((offset) => {
                    const osc = ctx.createOscillator();
                    const gain = ctx.createGain();
                    osc.type = 'sawtooth';

                    const startTime = now + offset;
                    osc.frequency.setValueAtTime(220, startTime);
                    osc.frequency.linearRampToValueAtTime(140, startTime + 0.08);

                    gain.gain.setValueAtTime(0.18, startTime);
                    gain.gain.exponentialRampToValueAtTime(0.001, startTime + 0.09);

                    osc.connect(gain);
                    gain.connect(ctx.destination);

                    osc.start(startTime);
                    osc.stop(startTime + 0.10);
                });
            });
        }
    };

    // Auto-initialize toggle button & dispatch sound on page load
    document.addEventListener('DOMContentLoaded', () => {
        SoundFX.updateToggleUI();

        const toggleBtn = document.getElementById('sound-toggle');
        if (toggleBtn) {
            toggleBtn.addEventListener('click', (e) => {
                e.preventDefault();
                e.stopPropagation();
                SoundFX.toggle();
            });
        }

        // Universal data-sound attribute trigger
        const soundEl = document.querySelector('[data-sound]');
        if (soundEl && soundEl.dataset.sound && typeof SoundFX[soundEl.dataset.sound] === 'function')
            SoundFX[soundEl.dataset.sound]();
    });

    window.SoundFX = SoundFX;
})();
