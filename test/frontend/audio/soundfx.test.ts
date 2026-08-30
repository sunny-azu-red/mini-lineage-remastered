import { describe, it, expect, beforeEach, vi } from 'vitest';
import { useGameStore } from '@/store/gameStore';
import { getAudioContext, playSound, type SoundName } from '@/audio/soundfx';

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

    // Browsers auto-suspend an AudioContext in a backgrounded tab, even after the initial
    // gesture-based unlock — every play defensively resumes so the sound isn't silently dropped
    // when the tab comes back to the foreground.
    it('resumes the shared context when it has been suspended', () => {
        useGameStore.setState({ soundEnabled: true });
        const ctx = getAudioContext() as unknown as { state: 'running' | 'suspended'; resume: () => Promise<void> };
        ctx.state = 'suspended';
        const resumeSpy = vi.spyOn(ctx, 'resume');

        playSound('buy');

        expect(resumeSpy).toHaveBeenCalledTimes(1);
        resumeSpy.mockRestore();
    });

    // Safari (and older iOS WebKit) only ever exposed the prefixed constructor.
    it('falls back to webkitAudioContext when the unprefixed constructor is missing', async () => {
        vi.resetModules();
        vi.stubGlobal('AudioContext', undefined);
        vi.stubGlobal('webkitAudioContext', FakeAudioContext);
        audioContextCtor.mockClear();

        const fresh = await import('@/audio/soundfx');
        const ctx = fresh.getAudioContext();

        expect(audioContextCtor).toHaveBeenCalledTimes(1);
        expect(ctx).toBeInstanceOf(FakeAudioContext);

        vi.unstubAllGlobals();
        vi.resetModules();
    });

    it('does not touch resume() when the context is already running', () => {
        useGameStore.setState({ soundEnabled: true });
        const ctx = getAudioContext() as unknown as { state: 'running' | 'suspended'; resume: () => Promise<void> };
        ctx.state = 'running';
        const resumeSpy = vi.spyOn(ctx, 'resume');

        playSound('buy');

        expect(resumeSpy).not.toHaveBeenCalled();
        resumeSpy.mockRestore();
    });
});
