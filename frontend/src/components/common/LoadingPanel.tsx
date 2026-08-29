// Shown in the main panel while waiting for the server's initial `hydrate` push (catalog/player
// still null — see gameStore.ts's initial state). Without this, the panel body is just empty
// (every screen component guards on `if (!catalog) return null`), which reads as a broken/empty
// page for the brief-but-real window covering the bootstrap fetch + socket handshake + hydrate.
export default function LoadingPanel() {
    return (
        <div className="loading-panel">
            <div className="loading-spinner" />
            <span>Entering the realm…</span>
        </div>
    );
}
