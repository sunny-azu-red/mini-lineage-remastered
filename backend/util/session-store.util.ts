import { sessionStore } from '@/config/database.config';

/** Promisified express-mysql-session accessors; callers decide how to handle a store error. */
export function getSessionData(sessionId: string): Promise<Record<string, any> | null> {
    return new Promise((resolve, reject) => {
        sessionStore.get(sessionId, (err, session) => err ? reject(err) : resolve((session as Record<string, any>) ?? null));
    });
}

export function setSessionData(sessionId: string, data: Record<string, any>): Promise<void> {
    return new Promise((resolve, reject) => {
        sessionStore.set(sessionId, data as any, (err) => err ? reject(err) : resolve());
    });
}
