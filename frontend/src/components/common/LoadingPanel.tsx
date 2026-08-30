interface LoadingPanelProps {
    /** Defaults to the app-boot wording; screens fetching their own data pass something apt. */
    label?: string;
}

// Shown while waiting on data: the server's initial `hydrate` push (AppShell), or a screen's own
// fetch. Without it the panel body is simply empty, which reads as a broken page — or worse, as a
// confident "there is nothing here" when the request is merely still in flight.
export default function LoadingPanel({ label = 'Entering the realm…' }: LoadingPanelProps) {
    return (
        <div className="loading-panel">
            <div className="loading-spinner" />
            <span>{label}</span>
        </div>
    );
}
