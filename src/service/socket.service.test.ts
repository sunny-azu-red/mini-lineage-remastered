import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';

const { mockIo, mockSocket } = vi.hoisted(() => {
    const mSocket = {
        id: 'socket-1',
        request: { session: { id: 'session-1' } },
        on: vi.fn(),
        emit: vi.fn(),
    };
    const mIo = {
        use: vi.fn(),
        on: vi.fn(),
        sockets: {
            sockets: {
                get: vi.fn(() => mSocket),
            }
        }
    };
    return {
        mockSocket: mSocket,
        mockIo: mIo
    };
});

vi.mock('socket.io', () => {
    const MockServer = vi.fn(function () {
        return mockIo;
    });
    return {
        Server: MockServer
    };
});

vi.mock('@/config/database.config', () => ({
    sessionStore: {
        get: vi.fn((_id: string, _cb: (err: any, session: any) => void) => { }),
        set: vi.fn((_id: string, _sess: any, cb: (err: any) => void) => cb(null)),
    }
}));

vi.mock('@/service/player.service', () => ({
    processTick: vi.fn(),
    isGameStarted: vi.fn(),
    getPlayerEffects: vi.fn().mockReturnValue([]),
    getPlayerStats: vi.fn().mockReturnValue({
        attack: 10,
        defense: 5,
        crit: 4,
        maxHealth: 100,
        regen: 1,
        ambushRisk: 8,
        xpMultiplier: 1,
        adenaMultiplier: 1,
    }),
    applyEffect: vi.fn(),
}));

vi.mock('@/util/lock.util', () => ({
    acquireSessionLock: vi.fn().mockResolvedValue(() => {}),
}));

vi.mock('@/repository/statistics.repository', () => ({
    statisticsRepository: {
        increment: vi.fn().mockResolvedValue(undefined),
    },
}));

import { initSocketService } from './socket.service';
import { sessionStore } from '@/config/database.config';
import * as playerService from '@/service/player.service';
import { TICK_CONFIG, EFFECTS_CONFIG } from '@/constant/game.constant';

describe('socketService', () => {
    const mockServer = {} as any;
    const mockMiddleware = vi.fn();

    beforeEach(() => {
        vi.useFakeTimers();
        vi.clearAllMocks();
    });

    afterEach(() => {
        vi.useRealTimers();
    });

    it('should initialize socket server and middleware', () => {
        initSocketService(mockServer, mockMiddleware);
        expect(mockIo.use).toHaveBeenCalled();
        expect(mockIo.on).toHaveBeenCalledWith('connection', expect.any(Function));
    });

    it('should handle player tick and emit updates', async () => {
        initSocketService(mockServer, mockMiddleware);

        // Simulate connection
        const connectionHandler = (mockIo.on as any).mock.calls.find((c: any) => c[0] === 'connection')[1];
        connectionHandler(mockSocket);

        // Setup mock data for tick
        const player = {
            health: 50,
            raceId: 0,
            effects: [{ ...EFFECTS_CONFIG.restingAura }]
        };
        vi.mocked(sessionStore.get as any).mockImplementation((_id: string, cb: any) => cb(null, player));
        vi.mocked(playerService.isGameStarted).mockReturnValue(true);
        vi.mocked(playerService.processTick).mockReturnValue(true); // health changed

        // Advance time to trigger interval
        vi.advanceTimersByTime(TICK_CONFIG.intervalMs);

        // The sessionStore.get and set are callbacks, so we need to wait for them to resolve
        await vi.runAllTicks();

        expect(sessionStore.get).toHaveBeenCalledWith('session-1', expect.any(Function));
        expect(playerService.processTick).toHaveBeenCalledWith(player, { applyRegen: true });
        expect(sessionStore.set).toHaveBeenCalledWith('session-1', player, expect.any(Function));
        expect(mockSocket.emit).toHaveBeenCalledWith('player_update', expect.any(Object));
    });

    it('should not emit update if processTick returns false (no changes)', async () => {
        initSocketService(mockServer, mockMiddleware);
        const connectionHandler = (mockIo.on as any).mock.calls.find((c: any) => c[0] === 'connection')[1];
        connectionHandler(mockSocket);

        const player = { health: 50, effects: [] };
        vi.mocked(sessionStore.get as any).mockImplementation((_id: string, cb: any) => cb(null, player));
        vi.mocked(playerService.isGameStarted).mockReturnValue(true);
        vi.mocked(playerService.processTick).mockReturnValue(false);

        mockSocket.emit.mockClear();
        vi.advanceTimersByTime(TICK_CONFIG.intervalMs);
        await vi.runAllTicks();

        expect(playerService.processTick).toHaveBeenCalledWith(player, { applyRegen: true });
        expect(mockSocket.emit).not.toHaveBeenCalled();
    });

    it('should clean up stale sessions after grace period', async () => {
        initSocketService(mockServer, mockMiddleware);

        // Connect and then disconnect
        const connectionHandler = (mockIo.on as any).mock.calls.find((c: any) => c[0] === 'connection')[1];
        connectionHandler(mockSocket);

        const disconnectHandler = (mockSocket.on as any).mock.calls.find((c: any) => c[0] === 'disconnect')[1];
        disconnectHandler();

        // Advance beyond grace period (10s)
        vi.advanceTimersByTime(11_000);

        // Trigger the tick check
        vi.advanceTimersByTime(TICK_CONFIG.intervalMs);
        await vi.runAllTicks();

        // If it's cleaned up, it won't call sessionStore.get
        vi.clearAllMocks();
        vi.advanceTimersByTime(TICK_CONFIG.intervalMs);
        expect(sessionStore.get).not.toHaveBeenCalled();
    });
    it('should register secure events and validate payloads', () => {
        initSocketService(mockServer, mockMiddleware);

        const connectionHandler = (mockIo.on as any).mock.calls.find((c: any) => c[0] === 'connection')[1];
        connectionHandler(mockSocket);

        const inputHandler = (mockSocket.on as any).mock.calls.find((c: any) => c[0] === 'input')[1];
        expect(inputHandler).toBeDefined();

        // Test invalid payload
        expect(() => inputHandler({ key: '' })).not.toThrow();

        // Test valid payload
        expect(() => inputHandler({ key: 'arrowup' })).not.toThrow();
    });

    it('should gracefully handle session reload errors', async () => {
        initSocketService(mockServer, mockMiddleware);
        const connectionHandler = (mockIo.on as any).mock.calls.find((c: any) => c[0] === 'connection')[1];
        connectionHandler(mockSocket);

        vi.mocked(sessionStore.get as any).mockImplementation((_id: string, cb: any) => cb(new Error('Reload fail')));
        
        vi.advanceTimersByTime(TICK_CONFIG.intervalMs);
        await vi.runAllTicks();

        expect(playerService.processTick).not.toHaveBeenCalled();
    });

    it('should skip tick if player is missing from session', async () => {
        initSocketService(mockServer, mockMiddleware);
        const connectionHandler = (mockIo.on as any).mock.calls.find((c: any) => c[0] === 'connection')[1];
        connectionHandler(mockSocket);

        vi.mocked(sessionStore.get as any).mockImplementation((_id: string, cb: any) => cb(null, null));
        
        vi.advanceTimersByTime(TICK_CONFIG.intervalMs);
        await vi.runAllTicks();

        expect(playerService.processTick).not.toHaveBeenCalled();
    });

    it('should skip connection handling if session is missing', () => {
        initSocketService(mockServer, mockMiddleware);
        const connectionHandler = (mockIo.on as any).mock.calls.find((c: any) => c[0] === 'connection')[1];
        
        const socketWithoutSession = { ...mockSocket, request: {} };
        expect(() => connectionHandler(socketWithoutSession)).not.toThrow();
    });

    it('should skip secure event if session is missing', () => {
        initSocketService(mockServer, mockMiddleware);
        const connectionHandler = (mockIo.on as any).mock.calls.find((c: any) => c[0] === 'connection')[1];
        connectionHandler(mockSocket);

        const inputHandler = (mockSocket.on as any).mock.calls.find((c: any) => c[0] === 'input')[1];
        
        // Mock socket.request to have no session
        const originalRequest = mockSocket.request;
        (mockSocket as any).request = {};
        
        expect(() => inputHandler({ key: 'arrowup' })).not.toThrow();
        
        (mockSocket as any).request = originalRequest;
    });

    it('should handle tick when game is not started', async () => {
        initSocketService(mockServer, mockMiddleware);
        const connectionHandler = (mockIo.on as any).mock.calls.find((c: any) => c[0] === 'connection')[1];
        connectionHandler(mockSocket);

        vi.mocked(sessionStore.get as any).mockImplementation((_id: string, cb: any) => cb(null, {}));
        vi.mocked(playerService.isGameStarted).mockReturnValue(false);

        vi.advanceTimersByTime(TICK_CONFIG.intervalMs);
        await vi.runAllTicks();

        expect(playerService.processTick).not.toHaveBeenCalled();
    });

    it('should handle tick when no changes occur', async () => {
        initSocketService(mockServer, mockMiddleware);
        const connectionHandler = (mockIo.on as any).mock.calls.find((c: any) => c[0] === 'connection')[1];
        connectionHandler(mockSocket);

        const player = {
            effects: [{ ...EFFECTS_CONFIG.restingAura }]
        };
        vi.mocked(sessionStore.get as any).mockImplementation((_id: string, cb: any) => cb(null, player));
        vi.mocked(playerService.isGameStarted).mockReturnValue(true);
        vi.mocked(playerService.processTick).mockReturnValue(false);

        vi.advanceTimersByTime(TICK_CONFIG.intervalMs);
        await vi.runAllTicks();

        expect(sessionStore.set).not.toHaveBeenCalled();
    });

    it('should handle session store save errors gracefully', async () => {
        initSocketService(mockServer, mockMiddleware);
        const connectionHandler = (mockIo.on as any).mock.calls.find((c: any) => c[0] === 'connection')[1];
        connectionHandler(mockSocket);
        
        // Clear initial connection emit
        mockSocket.emit.mockClear();

        const player = {
            effects: [{ ...EFFECTS_CONFIG.restingAura }]
        };
        vi.mocked(sessionStore.get as any).mockImplementation((_id: string, cb: any) => cb(null, player));
        vi.mocked(sessionStore.set as any).mockImplementation((_id: string, _sess: any, cb: any) => cb(new Error('Save failed')));
        vi.mocked(playerService.isGameStarted).mockReturnValue(true);
        vi.mocked(playerService.processTick).mockReturnValue(true);

        vi.advanceTimersByTime(TICK_CONFIG.intervalMs);
        await vi.runAllTicks();

        expect(playerService.processTick).toHaveBeenCalled();
        expect(mockSocket.emit).not.toHaveBeenCalledWith('player_update', expect.anything());
    });

    it('should handle input with missing payload', () => {
        initSocketService(mockServer, mockMiddleware);
        const connectionHandler = (mockIo.on as any).mock.calls.find((c: any) => c[0] === 'connection')[1];
        connectionHandler(mockSocket);

        const inputHandler = (mockSocket.on as any).mock.calls.find((c: any) => c[0] === 'input')[1];
        expect(() => inputHandler(undefined)).not.toThrow();
    });

    it('should execute socket middleware', () => {
        initSocketService(mockServer, mockMiddleware);
        const middleware = (mockIo.use as any).mock.calls[0][0];
        const next = vi.fn();
        middleware(mockSocket, next);
        expect(mockMiddleware).toHaveBeenCalled();
    });

    it('should do nothing if initialized with null server', () => {
        expect(() => initSocketService(null as any, mockMiddleware)).not.toThrow();
    });

    it('should handle disconnect without sessionId', () => {
        initSocketService(mockServer, mockMiddleware);
        const connectionHandler = (mockIo.on as any).mock.calls.find((c: any) => c[0] === 'connection')[1];
        
        // Mock socket without session
        const socketNoSession = { ...mockSocket, id: 'no-sid', on: vi.fn(), request: {} };
        connectionHandler(socketNoSession);
        
        const disconnectHandler = (socketNoSession.on as any).mock.calls.find((c: any) => c[0] === 'disconnect')[1];
        expect(() => disconnectHandler()).not.toThrow();
    });

    it('should handle disconnect with sessionId and existing tracker', () => {
        initSocketService(mockServer, mockMiddleware);
        const connectionHandler = (mockIo.on as any).mock.calls.find((c: any) => c[0] === 'connection')[1];
        connectionHandler(mockSocket);

        const disconnectHandler = (mockSocket.on as any).mock.calls.find((c: any) => c[0] === 'disconnect')[1];
        expect(() => disconnectHandler()).not.toThrow();
    });

    it('should handle secret input sequence and apply Konami cheat effect', async () => {
        initSocketService(mockServer, mockMiddleware);
        const connectionHandler = (mockIo.on as any).mock.calls.find((c: any) => c[0] === 'connection')[1];
        connectionHandler(mockSocket);

        const inputHandler = (mockSocket.on as any).mock.calls.find((c: any) => c[0] === 'input')[1];
        expect(inputHandler).toBeDefined();

        const player: any = { health: 100, raceId: 0, dead: false };
        vi.mocked(sessionStore.get as any).mockImplementation((_id: string, cb: any) => cb(null, player));
        vi.mocked(playerService.isGameStarted).mockReturnValue(true);

        const sequence = ['arrowup', 'arrowup', 'arrowdown', 'arrowdown', 'arrowleft', 'arrowright', 'arrowleft', 'arrowright', 'b', 'a'];
        for (const key of sequence) {
            inputHandler({ key });
        }
        await vi.runAllTicks();

        expect(playerService.applyEffect).toHaveBeenCalled();
        expect(player.cheated).toBe(true);
        expect(player.coward).toBe(true);
        expect(sessionStore.set).toHaveBeenCalledWith('session-1', player, expect.any(Function));
    });

    it('should ignore input when sequence is incorrect or incomplete', async () => {
        initSocketService(mockServer, mockMiddleware);
        const connectionHandler = (mockIo.on as any).mock.calls.find((c: any) => c[0] === 'connection')[1];
        connectionHandler(mockSocket);

        const inputHandler = (mockSocket.on as any).mock.calls.find((c: any) => c[0] === 'input')[1];
        expect(inputHandler).toBeDefined();

        const player: any = { health: 100, raceId: 0, dead: false, cheated: false };
        vi.mocked(sessionStore.get as any).mockImplementation((_id: string, cb: any) => cb(null, player));

        inputHandler({ key: 'arrowup' });
        inputHandler({ key: 'arrowdown' });
        inputHandler({ key: 'b' });
        await vi.runAllTicks();

        expect(player.cheated).toBe(false);
    });

    it('should not apply cheat effect if player is dead or game not started', async () => {
        initSocketService(mockServer, mockMiddleware);
        const connectionHandler = (mockIo.on as any).mock.calls.find((c: any) => c[0] === 'connection')[1];
        connectionHandler(mockSocket);

        const inputHandler = (mockSocket.on as any).mock.calls.find((c: any) => c[0] === 'input')[1];
        const deadPlayer: any = { health: 0, raceId: 0, dead: true, cheated: false };
        vi.mocked(sessionStore.get as any).mockImplementation((_id: string, cb: any) => cb(null, deadPlayer));
        vi.mocked(playerService.isGameStarted).mockReturnValue(true);

        const sequence = ['arrowup', 'arrowup', 'arrowdown', 'arrowdown', 'arrowleft', 'arrowright', 'arrowleft', 'arrowright', 'b', 'a'];
        for (const key of sequence) {
            inputHandler({ key });
        }
        await vi.runAllTicks();

        expect(deadPlayer.cheated).toBe(false);
    });

    it('should schedule exact timeout for active timed effects and process tick on expiry with applyRegen false', async () => {
        initSocketService(mockServer, mockMiddleware);
        const connectionHandler = (mockIo.on as any).mock.calls.filter((c: any) => c[0] === 'connection').at(-1)[1];

        const expiryTime = Date.now() + 1500;
        const player: any = {
            name: 'Hero',
            health: 125,
            raceId: 0,
            effects: [
                { ...EFFECTS_CONFIG.heartyMash, expiresAt: expiryTime }
            ]
        };

        vi.mocked(sessionStore.get as any).mockImplementation((_id: string, cb: any) => cb(null, player));
        vi.mocked(playerService.isGameStarted).mockReturnValue(true);
        vi.mocked(playerService.processTick).mockImplementation((p: any) => {
            p.health = 100;
            p.effects = [];
            return true;
        });

        connectionHandler(mockSocket);
        await vi.runAllTicks();

        expect(playerService.processTick).not.toHaveBeenCalled();

        // Advance time past the exact expiration delay
        vi.advanceTimersByTime(1600);
        await vi.runAllTicks();

        expect(playerService.processTick).toHaveBeenCalledWith(player, { applyRegen: false });
    });
});
