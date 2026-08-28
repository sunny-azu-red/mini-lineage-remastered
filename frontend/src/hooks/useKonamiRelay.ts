import { useEffect } from 'react';
import { socket } from '@/socket/client';

/**
 * Ported from the old app's global `window.addEventListener('keydown', ...)` handler
 * (`public/js/common.js`) — relays every non-repeated keydown outside of text inputs to the
 * server as the fire-and-forget `input` event, which `src/socket/handler/cheat.handler.ts`
 * listens for to drive the Konami cheat code. Mount this ONCE for the app's lifetime (from
 * App.tsx, alongside `useHistorySync()`) — like the old listener, it must stay active regardless
 * of which screen is currently showing.
 */
export function useKonamiRelay(): void {
    useEffect(() => {
        function handleKeyDown(e: KeyboardEvent): void {
            if (!e.key || e.repeat || e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement)
                return;

            socket.emit('input', { key: e.key.toLowerCase() });
        }

        window.addEventListener('keydown', handleKeyDown);
        return () => window.removeEventListener('keydown', handleKeyDown);
    }, []);
}
