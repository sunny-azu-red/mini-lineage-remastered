import { describe, it, expect, beforeEach } from 'vitest';
import { render } from '@testing-library/react';
import type { FlashView } from '@shared/contract';
import { useGameStore } from '@/store/gameStore';
import FlashAlert from '@/components/common/FlashAlert';

function setFlash(flash: FlashView | null) {
    useGameStore.setState({ flash }, false);
}

describe('FlashAlert', () => {
    beforeEach(() => {
        setFlash(null);
    });

    it('renders nothing when there is no flash', () => {
        const { container } = render(<FlashAlert />);

        expect(container).toBeEmptyDOMElement();
    });

    it.each<FlashView['type']>(['success', 'danger', 'info', 'warning'])(
        'maps flash.type "%s" onto the alert-%s modifier class',
        type => {
            setFlash({ text: 'A thing happened.', type });
            const { container } = render(<FlashAlert />);

            const alert = container.querySelector('.alert') as HTMLElement;
            expect(alert.className).toBe(`alert alert-${type}`);
        },
    );

    // Plan decision A12: flash.text is server-composed narrative HTML (never player-controlled),
    // so it renders through dangerouslySetInnerHTML rather than as escaped React children.
    it('renders the server-composed HTML in flash.text as real markup, not escaped text', () => {
        setFlash({ text: 'You gained <span class="xp">10 XP</span>!', type: 'success' });
        const { container } = render(<FlashAlert />);

        const xpSpan = container.querySelector('.alert .xp') as HTMLElement;
        expect(xpSpan).not.toBeNull();
        expect(xpSpan.tagName).toBe('SPAN');
        expect(xpSpan.textContent).toBe('10 XP');
        expect(container.textContent).toBe('You gained 10 XP!');
    });

    it('re-renders when the store flash changes and disappears again once it is cleared', () => {
        const { container, rerender } = render(<FlashAlert />);
        expect(container).toBeEmptyDOMElement();

        setFlash({ text: 'Purchased!', type: 'success' });
        rerender(<FlashAlert />);
        expect(container.querySelector('.alert-success')?.textContent).toBe('Purchased!');

        setFlash(null);
        rerender(<FlashAlert />);
        expect(container).toBeEmptyDOMElement();
    });
});
