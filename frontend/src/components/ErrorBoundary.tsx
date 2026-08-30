import { Component, type ErrorInfo, type ReactNode } from 'react';
import { useGameStore } from '@/store/gameStore';
import ErrorScreen from './screens/ErrorScreen';

/**
 * Catches a genuinely unexpected render-time throw anywhere in the tree — a bug, as opposed to
 * the store's modeled `screen: 'error'` state — and swaps in ErrorScreen rather than unmounting
 * to a blank page. The message is passed through only in a non-release build, mirroring
 * error.middleware.ts. `catalog.isRelease` is read off the vanilla store because a class
 * component can't call hooks; a one-shot read is fine since it never changes for a loaded page.
 */
export default class ErrorBoundary extends Component<{ children: ReactNode }, { error: Error | null }> {
    state: { error: Error | null } = { error: null };

    static getDerivedStateFromError(error: Error) {
        return { error };
    }

    componentDidCatch(error: Error, info: ErrorInfo): void {
        // eslint-disable-next-line no-console
        console.error('Uncaught render error', error, info.componentStack);
    }

    render(): ReactNode {
        if (!this.state.error)
            return this.props.children;

        const isRelease = useGameStore.getState().catalog?.isRelease ?? true;

        return <ErrorScreen detail={isRelease ? null : this.state.error.message} />;
    }
}
