import { Component, type ErrorInfo, type ReactNode } from 'react';
import { useGameStore } from '@/store/gameStore';
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
 * error's `message` is passed through as `ErrorScreen`'s `detail` ONLY in a non-release build —
 * mirroring the old `error.middleware.ts`'s `!isRelease(GAME_VERSION) ? err.message : null` gate,
 * which never leaked raw error text to a production user. `catalog.isRelease` (already sent on
 * every hydrate) is read directly off the vanilla store rather than via the `useGameStore` hook,
 * since a class component can't call hooks — this is a one-shot read at render time, which is
 * fine here since `isRelease` never changes for the lifetime of a loaded page.
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
        if (this.state.error) {
            const isRelease = useGameStore.getState().catalog?.isRelease ?? true;

            return <ErrorScreen detail={isRelease ? null : this.state.error.message} />;
        }

        return this.props.children;
    }
}
