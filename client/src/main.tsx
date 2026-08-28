import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import './styles/index.css';
import App from './App';
import { bootstrapSession, connectSocket, socket } from './socket/client';
import { useGameStore } from './store/gameStore';
import { installAudioUnlock } from './audio/unlock';

// Install the gesture-based AudioContext unlock before anything else — see unlock.ts's doc
// comment for why this (not a load-time autoplay) is what makes hack #1 (audio breaking on
// refresh) structurally impossible rather than merely less likely.
installAudioUnlock();

// Wire socket -> store BEFORE rendering, from module scope. Zustand's external-store model
// means the socket layer can write state directly with no provider-bridge component needed.
socket.on('hydrate', payload => useGameStore.getState().hydrate(payload));
socket.on('state:update', payload => useGameStore.getState().applyUpdate(payload));
socket.on('notice', flash => useGameStore.getState().setFlash(flash));
socket.on('connect', () => useGameStore.getState().setStatus('ready'));
socket.on('disconnect', () => useGameStore.getState().setStatus('disconnected'));

void (async () => {
    await bootstrapSession();
    connectSocket();
})();

createRoot(document.getElementById('root')!).render(
    <StrictMode>
        <App />
    </StrictMode>,
);
