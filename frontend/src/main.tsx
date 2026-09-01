import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import './styles/index.css';
import App from './App';
import { bootstrapSession, connectSocket, socket } from './socket/client';
import { useGameStore } from './store/gameStore';
import { installAudioUnlock } from './audio/unlock';

installAudioUnlock(); // before anything else — see unlock.ts

// Wire socket -> store directly (no provider-bridge component needed for zustand's external store).
const store = () => useGameStore.getState();
socket.on('hydrate', payload => store().hydrate(payload));
socket.on('state:update', payload => store().applyUpdate(payload));
socket.on('notice', flash => store().setFlash(flash));
socket.on('connect', () => store().setStatus('ready'));
socket.on('disconnect', () => store().setStatus('disconnected'));

void (async () => {
    await bootstrapSession();
    connectSocket();
})();

createRoot(document.getElementById('root')!).render(
    <StrictMode>
        <App />
    </StrictMode>,
);
