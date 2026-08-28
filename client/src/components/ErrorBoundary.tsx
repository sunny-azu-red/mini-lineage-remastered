import { Component, type ErrorInfo, type ReactNode } from 'react';
import ErrorScreen from './screens/ErrorScreen';

interface ErrorBoundaryProps {
    children: ReactNode;
}

interface ErrorBoundaryState {
    error: Error | null;
}

/**
 * Standard React class-component error boundary wrapping the whole app (see App.tsx). Covers a
 * DIFFERENT failure mode than the store's explicit `screen: 'error'` case (see ErrorScreen.tsx's
 * doc comment): this one catches a genuinely unexpected render-time throw anywhere in the tree —
 * a bug, not a modeled game-state condition — and swaps in `ErrorScreen` instead of unmounting
 * the whole React root to a blank page. `componentDidCatch` logs for diagnostics; the caught
 * error's `message` is passed through as `ErrorScreen`'s `detail`, mirroring the old
 * `error.middleware.ts`'s dev-mode detail line.
 */
export default class ErrorBoundary extends Component<ErrorBoundaryProps, ErrorBoundaryState> {
    state: ErrorBoundaryState = { error: null };

    static getDerivedStateFromError(error: Error): ErrorBoundaryState {
        return { error };
    }

    componentDidCatch(error: Error, info: ErrorInfo): void {
        // eslint-disable-next-line no-console
        console.error('Uncaught render error', error, info.componentStack);
    }

    render(): ReactNode {
        if (this.state.error)
            return <ErrorScreen detail={this.state.error.message} />;

        return this.props.children;
    }
}
