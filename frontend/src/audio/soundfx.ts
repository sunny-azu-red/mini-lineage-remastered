import { useGameStore } from '@/store/gameStore';

export type SoundName = 'crit' | 'eat' | 'level' | 'death' | 'buy' | 'start' | 'ambush';

let audioCtx: AudioContext | null = null;

/** Lazily-created singleton, exported so unlock.ts can resume it. Never auto-resumes on its own. */
export function getAudioContext(): AudioContext {
    if (!audioCtx) {
        const Ctor = window.AudioContext
            ?? (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
        audioCtx = new (Ctor as typeof AudioContext)();
    }

    return audioCtx;
}

/** A frequency automation point: ramp to `to` at `at` seconds past the note's start. */
interface Sweep {
    to: number;
    at: number;
    /** Exponential unless stated — linear is only used for the death slide. */
    linear?: boolean;
}

interface Note {
    /** Seconds after the sound's own start time. */
    offset: number;
    freq: number;
    type: OscillatorType;
    gain: number;
    /** How long the note's gain takes to decay to silence. */
    decay: number;
    /** Extra time the oscillator keeps running past `decay` before it is stopped. */
    tail: number;
    sweeps?: Sweep[];
}

type Voice = Omit<Note, 'offset' | 'freq'> & Partial<Pick<Note, 'offset' | 'freq'>>;

/** Builds one note per frequency, staggered by `every` seconds. */
function arpeggio(freqs: number[], every: number, voice: Voice): Note[] {
    return freqs.map((freq, idx) => ({ ...voice, freq, offset: idx * every } as Note));
}

// Every sound effect, declared as a list of notes; `playNote` below turns one into the oscillator/gain graph.
const SOUNDS: Record<SoundName, Note[]> = {
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

function playNote(ctx: AudioContext, start: number, note: Note): void {
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

/**
 * Plays a sound effect. No-ops when `name` is nullish or sound is muted. Defensively resumes a
 * suspended context each time — cheap, and covers a backgrounded tab re-suspended after unlock.
 */
export function playSound(name: SoundName | null | undefined): void {
    if (!name || !useGameStore.getState().soundEnabled)
        return;

    const ctx = getAudioContext();
    if (ctx.state === 'suspended')
        void ctx.resume();

    for (const note of SOUNDS[name])
        playNote(ctx, ctx.currentTime, note);
}
