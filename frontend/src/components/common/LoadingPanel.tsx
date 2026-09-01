interface LoadingPanelProps {
    /** Defaults to the app-boot wording; screens fetching their own data pass something apt. */
    label?: string;
}

// Shown while waiting on data (the initial hydrate, or a screen's own fetch) so an in-flight
// request never reads as a confident "there is nothing here".
export default function LoadingPanel({ label = 'Entering the realm…' }: LoadingPanelProps) {
    return (
        <div className="loading-panel">
            <div className="loading-spinner" />
            <span>{label}</span>
        </div>
    );
}
