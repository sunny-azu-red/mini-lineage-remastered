import { useEffect } from 'react';
import { socket } from '@/socket/client';

/**
 * Relays every non-repeated keydown outside a text input to the server as the fire-and-forget
 * `input` event, which drives the Konami cheat. Mount ONCE for the app's lifetime — like the old
 * global listener, it must stay active regardless of the current screen.
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
