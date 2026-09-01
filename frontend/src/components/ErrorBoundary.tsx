import { Component, type ErrorInfo, type ReactNode } from 'react';
import { useGameStore } from '@/store/gameStore';
import ErrorScreen from './screens/ErrorScreen';

/**
 * Catches a genuinely unexpected render-time throw — a bug, as opposed to the store's modeled
 * `screen: 'error'` state — and swaps in ErrorScreen. The message is passed through only in a
 * non-release build; `catalog.isRelease` is read off the vanilla store since a class component
 * can't call hooks.
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
