import { describe, it, expect, beforeEach, vi } from 'vitest';
import { useGameStore } from '@/store/gameStore';
import { playSound, type SoundName } from '@/audio/soundfx';

/**
 * A characterization test for the procedural synthesizer: it records the EXACT sequence of Web
 * Audio calls each sound makes — oscillator type, every frequency/gain automation point, the
 * node graph, and the start/stop times — and pins it.
 *
 * The other soundfx tests only assert that playing a sound doesn't throw, which cannot catch a
 * refactor that silently changes how the game SOUNDS. These traces can. If you deliberately
 * retune a sound, update the expected trace in the same commit.
 */

const trace: string[] = [];
const round = (v: number) => Number(v.toFixed(6));

class FakeParam {
    constructor(private readonly tag: string) { }
    setValueAtTime(v: number, t: number) { trace.push(`${this.tag}.setValueAtTime(${round(v)}, ${round(t)})`); return this; }
    linearRampToValueAtTime(v: number, t: number) { trace.push(`${this.tag}.linearRamp(${round(v)}, ${round(t)})`); return this; }
    exponentialRampToValueAtTime(v: number, t: number) { trace.push(`${this.tag}.expRamp(${round(v)}, ${round(t)})`); return this; }
}

let oscCount = 0;
let gainCount = 0;

class FakeOscillator {
    id = `osc${oscCount++}`;
    frequency = new FakeParam(`${this.id}.freq`);
    private stored = 'sine';
    set type(v: string) { trace.push(`${this.id}.type=${v}`); this.stored = v; }
    get type() { return this.stored; }
    connect(target: { id?: string }) { trace.push(`${this.id}.connect(${target.id ?? 'dest'})`); return target; }
    start(t: number) { trace.push(`${this.id}.start(${round(t)})`); }
    stop(t: number) { trace.push(`${this.id}.stop(${round(t)})`); }
}

class FakeGain {
    id = `gain${gainCount++}`;
    gain = new FakeParam(`${this.id}.gain`);
    connect(target: { id?: string }) { trace.push(`${this.id}.connect(${target.id ?? 'dest'})`); return target; }
}

class RecordingAudioContext {
    currentTime = 0;
    state = 'running';
    destination = {};
    createOscillator() { return new FakeOscillator(); }
    createGain() { return new FakeGain(); }
    resume() { return Promise.resolve(); }
}

function capture(name: SoundName): string[] {
    trace.length = 0;
    oscCount = 0;
    gainCount = 0;
    playSound(name);
    return [...trace];
}

const EXPECTED: Record<SoundName, string[]> = {
    crit: [
        "osc0.type=sawtooth",
        "osc0.freq.setValueAtTime(420, 0)",
        "osc0.freq.expRamp(60, 0.13)",
        "gain0.gain.setValueAtTime(0.18, 0)",
        "gain0.gain.expRamp(0.001, 0.15)",
        "osc0.connect(gain0)",
        "gain0.connect(dest)",
        "osc0.start(0)",
        "osc0.stop(0.16)",
    ],
    eat: [
        "osc0.type=triangle",
        "osc0.freq.setValueAtTime(330, 0)",
        "gain0.gain.setValueAtTime(0.14, 0)",
        "gain0.gain.expRamp(0.001, 0.12)",
        "osc0.connect(gain0)",
        "gain0.connect(dest)",
        "osc0.start(0)",
        "osc0.stop(0.13)",
        "osc1.type=triangle",
        "osc1.freq.setValueAtTime(440, 0.06)",
        "gain1.gain.setValueAtTime(0.14, 0.06)",
        "gain1.gain.expRamp(0.001, 0.18)",
        "osc1.connect(gain1)",
        "gain1.connect(dest)",
        "osc1.start(0.06)",
        "osc1.stop(0.19)",
        "osc2.type=triangle",
        "osc2.freq.setValueAtTime(660, 0.12)",
        "gain2.gain.setValueAtTime(0.14, 0.12)",
        "gain2.gain.expRamp(0.001, 0.24)",
        "osc2.connect(gain2)",
        "gain2.connect(dest)",
        "osc2.start(0.12)",
        "osc2.stop(0.25)",
    ],
    level: [
        "osc0.type=square",
        "osc0.freq.setValueAtTime(523.25, 0)",
        "gain0.gain.setValueAtTime(0.12, 0)",
        "gain0.gain.expRamp(0.001, 0.08)",
        "osc0.connect(gain0)",
        "gain0.connect(dest)",
        "osc0.start(0)",
        "osc0.stop(0.1)",
        "osc1.type=square",
        "osc1.freq.setValueAtTime(659.25, 0.09)",
        "gain1.gain.setValueAtTime(0.12, 0.09)",
        "gain1.gain.expRamp(0.001, 0.17)",
        "osc1.connect(gain1)",
        "gain1.connect(dest)",
        "osc1.start(0.09)",
        "osc1.stop(0.19)",
        "osc2.type=square",
        "osc2.freq.setValueAtTime(783.99, 0.18)",
        "gain2.gain.setValueAtTime(0.12, 0.18)",
        "gain2.gain.expRamp(0.001, 0.26)",
        "osc2.connect(gain2)",
        "gain2.connect(dest)",
        "osc2.start(0.18)",
        "osc2.stop(0.28)",
        "osc3.type=square",
        "osc3.freq.setValueAtTime(1046.5, 0.27)",
        "gain3.gain.setValueAtTime(0.12, 0.27)",
        "gain3.gain.expRamp(0.001, 0.65)",
        "osc3.connect(gain3)",
        "gain3.connect(dest)",
        "osc3.start(0.27)",
        "osc3.stop(0.67)",
    ],
    death: [
        "osc0.type=sawtooth",
        "osc0.freq.setValueAtTime(260, 0)",
        "osc0.freq.linearRamp(180, 0.18)",
        "osc0.freq.linearRamp(120, 0.36)",
        "osc0.freq.expRamp(45, 0.68)",
        "gain0.gain.setValueAtTime(0.16, 0)",
        "gain0.gain.expRamp(0.001, 0.7)",
        "osc0.connect(gain0)",
        "gain0.connect(dest)",
        "osc0.start(0)",
        "osc0.stop(0.72)",
    ],
    buy: [
        "osc0.type=sine",
        "osc0.freq.setValueAtTime(987.77, 0)",
        "gain0.gain.setValueAtTime(0.13, 0)",
        "gain0.gain.expRamp(0.001, 0.09)",
        "osc0.connect(gain0)",
        "gain0.connect(dest)",
        "osc0.start(0)",
        "osc0.stop(0.1)",
        "osc1.type=sine",
        "osc1.freq.setValueAtTime(1318.51, 0.07)",
        "gain1.gain.setValueAtTime(0.13, 0.07)",
        "gain1.gain.expRamp(0.001, 0.16)",
        "osc1.connect(gain1)",
        "gain1.connect(dest)",
        "osc1.start(0.07)",
        "osc1.stop(0.17)",
    ],
    start: [
        "osc0.type=triangle",
        "osc0.freq.setValueAtTime(293.66, 0)",
        "gain0.gain.setValueAtTime(0.14, 0)",
        "gain0.gain.expRamp(0.001, 0.12)",
        "osc0.connect(gain0)",
        "gain0.connect(dest)",
        "osc0.start(0)",
        "osc0.stop(0.14)",
        "osc1.type=triangle",
        "osc1.freq.setValueAtTime(369.99, 0.1)",
        "gain1.gain.setValueAtTime(0.14, 0.1)",
        "gain1.gain.expRamp(0.001, 0.22)",
        "osc1.connect(gain1)",
        "gain1.connect(dest)",
        "osc1.start(0.1)",
        "osc1.stop(0.24)",
        "osc2.type=triangle",
        "osc2.freq.setValueAtTime(440, 0.2)",
        "gain2.gain.setValueAtTime(0.14, 0.2)",
        "gain2.gain.expRamp(0.001, 0.34)",
        "osc2.connect(gain2)",
        "gain2.connect(dest)",
        "osc2.start(0.2)",
        "osc2.stop(0.36)",
        "osc3.type=square",
        "osc3.freq.setValueAtTime(587.33, 0.3)",
        "gain3.gain.setValueAtTime(0.14, 0.3)",
        "gain3.gain.expRamp(0.001, 0.75)",
        "osc3.connect(gain3)",
        "gain3.connect(dest)",
        "osc3.start(0.3)",
        "osc3.stop(0.77)",
    ],
    ambush: [
        "osc0.type=sawtooth",
        "osc0.freq.setValueAtTime(220, 0)",
        "osc0.freq.linearRamp(140, 0.08)",
        "gain0.gain.setValueAtTime(0.18, 0)",
        "gain0.gain.expRamp(0.001, 0.09)",
        "osc0.connect(gain0)",
        "gain0.connect(dest)",
        "osc0.start(0)",
        "osc0.stop(0.1)",
        "osc1.type=sawtooth",
        "osc1.freq.setValueAtTime(220, 0.11)",
        "osc1.freq.linearRamp(140, 0.19)",
        "gain1.gain.setValueAtTime(0.18, 0.11)",
        "gain1.gain.expRamp(0.001, 0.2)",
        "osc1.connect(gain1)",
        "gain1.connect(dest)",
        "osc1.start(0.11)",
        "osc1.stop(0.21)",
        "osc2.type=sawtooth",
        "osc2.freq.setValueAtTime(220, 0.22)",
        "osc2.freq.linearRamp(140, 0.3)",
        "gain2.gain.setValueAtTime(0.18, 0.22)",
        "gain2.gain.expRamp(0.001, 0.31)",
        "osc2.connect(gain2)",
        "gain2.connect(dest)",
        "osc2.start(0.22)",
        "osc2.stop(0.32)",
    ],
};

describe('soundfx — synthesized waveform traces', () => {
    beforeEach(() => {
        vi.stubGlobal('AudioContext', RecordingAudioContext);
        useGameStore.setState({ soundEnabled: true });
    });

    it.each(Object.keys(EXPECTED) as SoundName[])('"%s" emits its exact Web Audio call sequence', (name) => {
        expect(capture(name)).toEqual(EXPECTED[name]);
    });

    it('covers every sound the contract declares', () => {
        const declared: SoundName[] = ['crit', 'eat', 'level', 'death', 'buy', 'start', 'ambush'];
        expect(Object.keys(EXPECTED).sort()).toEqual([...declared].sort());
    });
});
