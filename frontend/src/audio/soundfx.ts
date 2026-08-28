import { useGameStore } from '@/store/gameStore';

export type SoundName = 'crit' | 'eat' | 'level' | 'death' | 'buy' | 'start' | 'ambush';

let audioCtx: AudioContext | null = null;

/**
 * Lazily initializes the singleton Web Audio `AudioContext`, exported so `audio/unlock.ts` can
 * share the same instance to `.resume()` it from a user-gesture listener. Unlike the old
 * `public/js/audio.js`, this module never auto-resumes on its own — resuming only ever happens
 * from a real gesture (unlock.ts) or defensively right before a sound plays (see `playSound`).
 */
export function getAudioContext(): AudioContext {
    if (!audioCtx) {
        const AudioContextClass =
            window.AudioContext ?? (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
        audioCtx = new (AudioContextClass as typeof AudioContext)();
    }
    return audioCtx;
}

/**
 * ⚔️ Critical Hit - Punchy 8-bit impact crunch with rapid pitch slide.
 */
function crit(ctx: AudioContext, now: number): void {
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
}

/**
 * 🍖 Eat / Food Heal - Ascending triple chime (vitality restore).
 */
function eat(ctx: AudioContext, now: number): void {
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
}

/**
 * ✨ Level Up - Triumphant 4-note retro fanfare (C5 -> E5 -> G5 -> C6).
 */
function level(ctx: AudioContext, now: number): void {
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
}

/**
 * 💀 Death - Slow melancholic downward game over slide.
 */
function death(ctx: AudioContext, now: number): void {
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
}

/**
 * 🪙 Purchase / Shop - Crisp double chime coin exchange.
 */
function buy(ctx: AudioContext, now: number): void {
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
}

/**
 * 🌟 Game Start - Heroic awakening fanfare (D4 -> F#4 -> A4 -> D5).
 */
function start(ctx: AudioContext, now: number): void {
    const notes: { freq: number; type: OscillatorType; dur: number }[] = [
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
}

/**
 * 💢 Ambush - Urgent dissonant retro alarm pulses.
 */
function ambush(ctx: AudioContext, now: number): void {
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
}

const SYNTHS: Record<SoundName, (ctx: AudioContext, now: number) => void> = {
    crit,
    eat,
    level,
    death,
    buy,
    start,
    ambush,
};

/**
 * Plays a retro synth sound effect. No-ops if `name` is nullish or if the store's
 * `soundEnabled` preference is off — reads the store directly (`getState()`, not a hook) since
 * this is called from non-component code such as a socket ack handler.
 *
 * Defensively `resume()`s the context if it's suspended every time (cheap, always safe) to cover
 * a backgrounded tab that got auto-suspended again after the initial gesture-based unlock.
 */
export function playSound(name: SoundName | null | undefined): void {
    if (!name)
        return;
    if (!useGameStore.getState().soundEnabled)
        return;

    const ctx = getAudioContext();
    if (ctx.state === 'suspended')
        void ctx.resume();

    SYNTHS[name](ctx, ctx.currentTime);
}
