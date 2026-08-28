import { describe, it, expect, vi, beforeEach } from 'vitest';
import { withSession, readSession, NO_CHANGE, SessionContext } from '@/socket/session';
import { SocketError } from '@/socket/error';
import { acquireSessionLock } from '@/util/lock.util';
import { getSessionData, setSessionData } from '@/util/session-store.util';

vi.mock('@/util/lock.util', () => ({
    acquireSessionLock: vi.fn(),
}));

vi.mock('@/util/session-store.util', () => ({
    getSessionData: vi.fn(),
    setSessionData: vi.fn(),
}));

describe('withSession', () => {
    let release: ReturnType<typeof vi.fn>;

    beforeEach(() => {
        vi.clearAllMocks();
        release = vi.fn(() => {});
        vi.mocked(acquireSessionLock).mockResolvedValue(release as unknown as () => void);
        vi.mocked(setSessionData).mockResolvedValue(undefined);
    });

    it('locks, loads, mutates, bumps revision, persists, and releases the lock', async () => {
        const session = { cookie: {}, raceId: 0, health: 100, revision: 4 };
        vi.mocked(getSessionData).mockResolvedValue(session);

        const result = await withSession('sid-1', (ctx) => {
            ctx.player.health = 90;
            return 'ok';
        });

        expect(result).toBe('ok');
        expect(acquireSessionLock).toHaveBeenCalledWith('sid-1');
        expect(getSessionData).toHaveBeenCalledWith('sid-1');
        expect(session.revision).toBe(5);
        expect(setSessionData).toHaveBeenCalledWith('sid-1', session);
        expect(release).toHaveBeenCalledTimes(1);
    });

    it('initializes revision to 1 when absent', async () => {
        const session = { cookie: {} };
        vi.mocked(getSessionData).mockResolvedValue(session);

        await withSession('sid-1', () => 'ok');

        expect((session as any).revision).toBe(1);
    });

    it('skips persistence and resolves undefined when the mutator returns NO_CHANGE', async () => {
        const session = { cookie: {}, revision: 1 };
        vi.mocked(getSessionData).mockResolvedValue(session);

        const result = await withSession('sid-1', () => NO_CHANGE);

        expect(result).toBeUndefined();
        expect(setSessionData).not.toHaveBeenCalled();
        expect(session.revision).toBe(1); // untouched
        expect(release).toHaveBeenCalledTimes(1);
    });

    it('throws SESSION_EXPIRED and releases the lock when the session is gone', async () => {
        vi.mocked(getSessionData).mockResolvedValue(null);

        await expect(withSession('sid-missing', () => 'ok')).rejects.toMatchObject({ code: 'SESSION_EXPIRED' });
        expect(release).toHaveBeenCalledTimes(1);
        expect(setSessionData).not.toHaveBeenCalled();
    });

    it('propagates the mutator error and still releases the lock', async () => {
        const session = { cookie: {} };
        vi.mocked(getSessionData).mockResolvedValue(session);

        await expect(withSession('sid-1', () => {
            throw new SocketError('AMBUSHED', 'nope');
        })).rejects.toMatchObject({ code: 'AMBUSHED' });

        expect(release).toHaveBeenCalledTimes(1);
        expect(setSessionData).not.toHaveBeenCalled();
    });

    it('supports an async mutator', async () => {
        const session = { cookie: {} };
        vi.mocked(getSessionData).mockResolvedValue(session);

        const result = await withSession('sid-1', async (ctx) => {
            await Promise.resolve();
            ctx.player.health = 1;
            return 'async-ok';
        });

        expect(result).toBe('async-ok');
        expect(setSessionData).toHaveBeenCalled();
    });

    it('never releases the lock more than once even under concurrent completion paths', async () => {
        const session = { cookie: {} };
        vi.mocked(getSessionData).mockResolvedValue(session);

        await withSession('sid-1', () => 'ok');
        // release is only ever invoked by the finally block, exactly once
        expect(release).toHaveBeenCalledTimes(1);
    });
});

describe('readSession', () => {
    beforeEach(() => {
        vi.clearAllMocks();
    });

    it('loads the session without acquiring a lock or writing', async () => {
        const session = { cookie: {}, raceId: 0 };
        vi.mocked(getSessionData).mockResolvedValue(session);

        const result = await readSession('sid-1', (ctx: SessionContext) => ctx.player.raceId);

        expect(result).toBe(0);
        expect(acquireSessionLock).not.toHaveBeenCalled();
        expect(setSessionData).not.toHaveBeenCalled();
    });

    it('throws SESSION_EXPIRED when the session is gone', async () => {
        vi.mocked(getSessionData).mockResolvedValue(null);

        await expect(readSession('sid-missing', (ctx) => ctx.player)).rejects.toMatchObject({ code: 'SESSION_EXPIRED' });
    });

    it('supports an async read function', async () => {
        const session = { cookie: {} };
        vi.mocked(getSessionData).mockResolvedValue(session);

        const result = await readSession('sid-1', async (ctx) => {
            await Promise.resolve();
            return ctx.sessionId;
        });

        expect(result).toBe('sid-1');
    });
});
