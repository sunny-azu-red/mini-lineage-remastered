import { describe, it, expect, beforeEach, vi } from 'vitest';
import { useGameStore } from '@/store/gameStore';
import { playSound, type SoundName } from '@/audio/soundfx';

// jsdom has no Web Audio API at all, so we stub the couple of methods/properties actually
// exercised by soundfx.ts's synth functions: createOscillator/createGain, .connect, .start,
// .stop, .currentTime, and the gain/frequency AudioParam methods
// (setValueAtTime/linearRampToValueAtTime/exponentialRampToValueAtTime).
class FakeAudioParam {
    value = 0;
    setValueAtTime = vi.fn().mockReturnThis();
    linearRampToValueAtTime = vi.fn().mockReturnThis();
    exponentialRampToValueAtTime = vi.fn().mockReturnThis();
}

class FakeNode {
    connect = vi.fn().mockReturnThis();
}

class FakeOscillatorNode extends FakeNode {
    type = 'sine';
    frequency = new FakeAudioParam();
    start = vi.fn();
    stop = vi.fn();
}

class FakeGainNode extends FakeNode {
    gain = new FakeAudioParam();
}

export const audioContextCtor = vi.fn();

class FakeAudioContext {
    currentTime = 0;
    state: 'running' | 'suspended' = 'running';
    destination = {};

    constructor() {
        audioContextCtor();
    }

    createOscillator() {
        return new FakeOscillatorNode();
    }

    createGain() {
        return new FakeGainNode();
    }

    resume() {
        this.state = 'running';
        return Promise.resolve();
    }
}

describe('soundfx', () => {
    beforeEach(() => {
        vi.stubGlobal('AudioContext', FakeAudioContext);
        audioContextCtor.mockClear();
    });

    it('is a no-op when soundEnabled is false — never constructs an AudioContext', () => {
        useGameStore.setState({ soundEnabled: false });

        playSound('crit');

        expect(audioContextCtor).not.toHaveBeenCalled();
    });

    it('is a no-op for a null/undefined sound name even when soundEnabled is true', () => {
        useGameStore.setState({ soundEnabled: true });

        expect(() => playSound(null)).not.toThrow();
        expect(() => playSound(undefined)).not.toThrow();
        expect(audioContextCtor).not.toHaveBeenCalled();
    });

    const names: SoundName[] = ['crit', 'eat', 'level', 'death', 'buy', 'start', 'ambush'];

    it.each(names)('plays "%s" without throwing when soundEnabled is true', (name) => {
        useGameStore.setState({ soundEnabled: true });

        expect(() => playSound(name)).not.toThrow();
    });
});
