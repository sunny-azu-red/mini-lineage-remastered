import { sessionStore } from '@/config/database.config';

/**
 * Promisified wrappers around the express-mysql-session `sessionStore`.
 * Callers decide how to handle a rejected promise (store error) — these
 * helpers only normalize the Node-style (err, result) callback shape.
 */

export function getSessionData(sessionId: string): Promise<Record<string, any> | null> {
    return new Promise((resolve, reject) => {
        sessionStore.get(sessionId, (err, session) => {
            if (err)
                return reject(err);

            if (!session)
                return resolve(null);

            resolve(session as Record<string, any>);
        });
    });
}

export function setSessionData(sessionId: string, data: Record<string, any>): Promise<void> {
    return new Promise((resolve, reject) => {
        sessionStore.set(sessionId, data as any, (err) => {
            if (err)
                return reject(err);

            resolve();
        });
    });
}
