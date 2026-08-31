import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import './styles/index.css';
import App from './App';
import { bootstrapSession, connectSocket, socket } from './socket/client';
import { syncClock } from './socket/clock';
import { useGameStore } from './store/gameStore';
import { installAudioUnlock } from './audio/unlock';

// Before anything else — see unlock.ts for why a gesture-based unlock (not a load-time autoplay)
// is what makes audio-breaks-on-refresh structurally impossible.
installAudioUnlock();

// Wire socket -> store from module scope, before rendering. Zustand's external-store model means
// the socket layer writes state directly, with no provider-bridge component.
const store = () => useGameStore.getState();
socket.on('hydrate', payload => store().hydrate(payload));
socket.on('state:update', payload => store().applyUpdate(payload));
socket.on('notice', flash => store().setFlash(flash));
socket.on('connect', () => {
    store().setStatus('ready');
    // Also fires on every RECONNECT, which is what happens after the machine sleeps — precisely
    // when the two clocks are most likely to have drifted apart.
    void syncClock();
});
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
