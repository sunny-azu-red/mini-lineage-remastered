import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';

describe('env.config', () => {
    const originalEnv = process.env;

    beforeEach(() => {
        vi.resetModules();
        process.env = { ...originalEnv };
    });

    afterEach(() => {
        process.env = originalEnv;
    });

    it('should use default values in test environment', async () => {
        const { env } = await import('@/config/env.config');
        expect(env.NODE_ENV).toBe('test');
        expect(env.SESSION_SECRET).toBe('your-secret-here');
    });

    it('should use nonEmptyStr validator when not in test mode', async () => {
        // We simulate a non-test environment by overriding NODE_ENV before import
        process.env.NODE_ENV = 'development';
        process.env.SESSION_SECRET = 'secret123';
        
        const { env } = await import('@/config/env.config');
        expect(env.SESSION_SECRET).toBe('secret123');
    });

    it('reports an invalid env and exits when SESSION_SECRET is empty outside test mode', async () => {
        // Outside NODE_ENV=test, SESSION_SECRET has no default at all, so an empty string is
        // handed straight to the `nonEmptyStr` validator, whose `throw new Error('Cannot be
        // empty')` is the only thing standing between a production boot and an unsigned
        // session cookie. envalid catches that, hands it to its default reporter, and the
        // reporter terminates the process — stubbed here so the run survives to assert it.
        process.env.NODE_ENV = 'development';
        process.env.SESSION_SECRET = '';

        // envalid's default reporter prints its "Invalid environment variables" banner (expected
        // noise in this one test's output) and then terminates the process — stubbed so the run
        // survives long enough to assert on it.
        const exitSpy = vi.spyOn(process, 'exit').mockImplementation((() => undefined) as never);

        const { env } = await import('@/config/env.config');

        expect(exitSpy).toHaveBeenCalledWith(1);
        // envalid never validated the var (the validator threw), so its strict proxy refuses to
        // hand the raw empty string back — proof the throw fired rather than the value slipping
        // through, which in a real deployment would mean an unsigned session cookie secret.
        expect(() => env.SESSION_SECRET).toThrow(/SESSION_SECRET/);

        exitSpy.mockRestore();
    });

});
