/**
 * Procedural 8-bit Web Audio synth. No assets: every sound is built from oscillators and gain
 * envelopes at play time. Ported from the reference implementation with the SOUNDS table
 * unchanged — retuning a voice is a deliberate change, not a side effect of the port.
 */

let audioCtx = null;
let enabled = true;

/** Lazily-created singleton. Never auto-resumes on its own; `installUnlock` does that. */
export function getAudioContext() {
    if (!audioCtx) {
        const Ctor = window.AudioContext ?? window.webkitAudioContext;
        audioCtx = new Ctor();
    }

    return audioCtx;
}

/** Builds one note per frequency, staggered by `every` seconds. */
function arpeggio(freqs, every, voice) {
    return freqs.map((freq, idx) => ({ ...voice, freq, offset: idx * every }));
}

// Every sound effect, declared as a list of notes; `playNote` turns one into the oscillator graph.
const SOUNDS = {
    // ⚔️ Punchy 8-bit impact crunch with a rapid pitch slide.
    crit: [{
        offset: 0, freq: 420, type: 'sawtooth', gain: 0.18, decay: 0.15, tail: 0.01,
        sweeps: [{ to: 60, at: 0.13 }],
    }],

    // 🍖 Ascending triple chime — vitality restored.
    eat: arpeggio([330, 440, 660], 0.06, { type: 'triangle', gain: 0.14, decay: 0.12, tail: 0.01 }),

    // ✨ Triumphant 4-note retro fanfare (C5 -> E5 -> G5 -> C6); the final note rings out.
    level: arpeggio([523.25, 659.25, 783.99, 1046.50], 0.09, { type: 'square', gain: 0.12, decay: 0.08, tail: 0.02 })
        .map((note, idx, all) => (idx === all.length - 1 ? { ...note, decay: 0.38 } : note)),

    // 💀 Slow, melancholic downward game-over slide.
    death: [{
        offset: 0, freq: 260, type: 'sawtooth', gain: 0.16, decay: 0.70, tail: 0.02,
        sweeps: [
            { to: 180, at: 0.18, linear: true },
            { to: 120, at: 0.36, linear: true },
            { to: 45, at: 0.68 },
        ],
    }],

    // 🪙 Crisp double-chime coin exchange.
    buy: arpeggio([987.77, 1318.51], 0.07, { type: 'sine', gain: 0.13, decay: 0.09, tail: 0.01 }),

    // 🌟 Heroic awakening fanfare (D4 -> F#4 -> A4 -> D5).
    start: [
        { offset: 0.00, freq: 293.66, type: 'triangle', gain: 0.14, decay: 0.12, tail: 0.02 },
        { offset: 0.10, freq: 369.99, type: 'triangle', gain: 0.14, decay: 0.12, tail: 0.02 },
        { offset: 0.20, freq: 440.00, type: 'triangle', gain: 0.14, decay: 0.14, tail: 0.02 },
        { offset: 0.30, freq: 587.33, type: 'square', gain: 0.14, decay: 0.45, tail: 0.02 },
    ],

    // 💢 Urgent, dissonant retro alarm pulses.
    ambush: arpeggio([220, 220, 220], 0.11, {
        type: 'sawtooth', gain: 0.18, decay: 0.09, tail: 0.01,
        sweeps: [{ to: 140, at: 0.08, linear: true }],
    }),
};

function playNote(ctx, start, note) {
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = note.type;

    const at = start + note.offset;
    osc.frequency.setValueAtTime(note.freq, at);
    for (const sweep of note.sweeps ?? []) {
        const ramp = sweep.linear ? 'linearRampToValueAtTime' : 'exponentialRampToValueAtTime';
        osc.frequency[ramp](sweep.to, at + sweep.at);
    }

    gain.gain.setValueAtTime(note.gain, at);
    gain.gain.exponentialRampToValueAtTime(0.001, at + note.decay);

    osc.connect(gain);
    gain.connect(ctx.destination);

    osc.start(at);
    osc.stop(at + note.decay + note.tail);
}

export function soundEnabled() {
    return enabled;
}

export function setSoundEnabled(value) {
    enabled = value;
    try {
        localStorage.setItem('soundEnabled', value ? '1' : '0');
    } catch {
        // Private mode or blocked storage — the preference just will not persist.
    }
}

export function restoreSoundPreference() {
    try {
        enabled = localStorage.getItem('soundEnabled') !== '0';
    } catch {
        enabled = true;
    }

    return enabled;
}

/** No-ops when `name` is unknown or sound is muted. */
export function playSound(name) {
    if (!name || !enabled || !SOUNDS[name])
        return;

    const ctx = getAudioContext();
    // Defensive: covers a backgrounded tab re-suspended after unlock.
    if (ctx.state === 'suspended')
        void ctx.resume();

    for (const note of SOUNDS[name])
        playNote(ctx, ctx.currentTime, note);
}

/**
 * Resumes the shared AudioContext on the very first user gesture anywhere on the page, so the
 * context is always unlocked before anything asks to play a sound.
 */
export function installUnlock() {
    const unlock = () => {
        try {
            const ctx = getAudioContext();
            if (ctx.state === 'suspended')
                void ctx.resume();
        } catch {
            // Web Audio unavailable in this browser — nothing to unlock.
        }
    };

    for (const event of ['pointerdown', 'keydown'])
        window.addEventListener(event, unlock, { capture: true, once: true });
}
