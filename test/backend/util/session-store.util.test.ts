import { describe, it, expect, vi, beforeEach } from 'vitest';
import { getSessionData, setSessionData } from '@/util/session-store.util';
import { sessionStore } from '@/config/database.config';

vi.mock('@/config/database.config', () => ({
    sessionStore: {
        get: vi.fn(),
        set: vi.fn(),
    },
}));

describe('session-store.util', () => {
    beforeEach(() => {
        vi.clearAllMocks();
    });

    // sessionStore.get/set are typed via express-mysql-session's overloaded (callback | promise)
    // signatures, which confuses vi.mocked()'s inference against a plain (id, cb) => void
    // implementation. Going through `as any` sidesteps the overload-resolution mismatch — the
    // mock's actual runtime shape (set by the vi.mock factory above) is what matters here, not
    // the compile-time overload TS happens to pick.
    const mockedGet = sessionStore.get as any;
    const mockedSet = sessionStore.set as any;

    describe('getSessionData', () => {
        it('resolves with the session data on success', async () => {
            mockedGet.mockImplementation((_id: string, cb: any) => cb(null, { name: 'Arthur' }));

            const result = await getSessionData('sid-1');
            expect(result).toEqual({ name: 'Arthur' });
            expect(sessionStore.get).toHaveBeenCalledWith('sid-1', expect.any(Function));
        });

        it('resolves null when the store returns no session', async () => {
            mockedGet.mockImplementation((_id: string, cb: any) => cb(null, null));

            const result = await getSessionData('sid-missing');
            expect(result).toBeNull();
        });

        it('resolves null when the store returns undefined', async () => {
            mockedGet.mockImplementation((_id: string, cb: any) => cb(null, undefined));

            const result = await getSessionData('sid-missing');
            expect(result).toBeNull();
        });

        it('rejects when the store errors', async () => {
            const err = new Error('db down');
            mockedGet.mockImplementation((_id: string, cb: any) => cb(err));

            await expect(getSessionData('sid-err')).rejects.toThrow('db down');
        });
    });

    describe('setSessionData', () => {
        it('resolves when the store saves successfully', async () => {
            mockedSet.mockImplementation((_id: string, _data: any, cb: any) => cb());

            await expect(setSessionData('sid-1', { name: 'Arthur' })).resolves.toBeUndefined();
            expect(sessionStore.set).toHaveBeenCalledWith('sid-1', { name: 'Arthur' }, expect.any(Function));
        });

        it('rejects when the store errors', async () => {
            const err = new Error('write failed');
            mockedSet.mockImplementation((_id: string, _data: any, cb: any) => cb(err));

            await expect(setSessionData('sid-1', {})).rejects.toThrow('write failed');
        });
    });
});
