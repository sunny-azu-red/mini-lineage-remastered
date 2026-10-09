/** Procedural 8-bit Web Audio synth: every sound is oscillators and gain envelopes, no assets. */
import { keep, recall } from './hooks/kept';

let audioCtx = null;

/** Lazily-created singleton. Never auto-resumes on its own; `installUnlock` does that. */
function getAudioContext() {
    if (!audioCtx) {
        const Ctor = window.AudioContext ?? window.webkitAudioContext;
        audioCtx = new Ctor();
    }

    return audioCtx;
}

// Every sound effect, declared as a list of notes; `playNote` turns one into the oscillator graph.
const SOUNDS = {
    // 🌟 Heroic awakening fanfare (D4 -> F#4 -> A4 -> D5), for a character made.
    start: [
        { offset: 0.00, freq: 293.66, type: 'triangle', gain: 0.14, decay: 0.12, tail: 0.02 },
        { offset: 0.10, freq: 369.99, type: 'triangle', gain: 0.14, decay: 0.12, tail: 0.02 },
        { offset: 0.20, freq: 440.00, type: 'triangle', gain: 0.14, decay: 0.14, tail: 0.02 },
        { offset: 0.30, freq: 587.33, type: 'square', gain: 0.14, decay: 0.45, tail: 0.02 },
    ],

    // 🔊 Crisp double chime, so turning sound on is heard to have worked.
    toggle: [
        { offset: 0.00, freq: 987.77, type: 'sine', gain: 0.13, decay: 0.09, tail: 0.01 },
        { offset: 0.07, freq: 1318.51, type: 'sine', gain: 0.13, decay: 0.09, tail: 0.01 },
    ],
};

function playNote(ctx, start, note) {
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = note.type;

    const at = start + note.offset;
    osc.frequency.setValueAtTime(note.freq, at);
    gain.gain.setValueAtTime(note.gain, at);
    gain.gain.exponentialRampToValueAtTime(0.001, at + note.decay);

    osc.connect(gain);
    gain.connect(ctx.destination);

    osc.start(at);
    osc.stop(at + note.decay + note.tail);
}

/** On unless the reader turned it off; only the off is kept. */
export function soundEnabled() {
    return recall('sound', 'effects') !== '0';
}

export function setSoundEnabled(on) {
    keep('sound', 'effects', on ? null : '0');
}

export function playSound(name) {
    if (!name || !soundEnabled() || !SOUNDS[name])
        return;

    const ctx = getAudioContext();
    // Defensive: covers a backgrounded tab re-suspended after unlock.
    if (ctx.state === 'suspended')
        void ctx.resume();

    for (const note of SOUNDS[name])
        playNote(ctx, ctx.currentTime, note);
}

/** Resumes the AudioContext on the first gesture, before anything can ask to play. */
export function installUnlock() {
    const unlock = () => {
        try {
            const ctx = getAudioContext();
            if (ctx.state === 'suspended')
                void ctx.resume();
        } catch {
            // Web Audio unavailable in this browser: nothing to unlock.
        }
    };

    for (const event of ['pointerdown', 'keydown'])
        window.addEventListener(event, unlock, { capture: true, once: true });
}
