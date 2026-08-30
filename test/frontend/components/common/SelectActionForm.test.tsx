import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import SelectActionForm from '@/components/common/SelectActionForm';

const OPTIONS = [
    { value: 'yes', label: 'Yes, stab yourself in the heart' },
    { value: 'no', label: 'No, I changed my mind' },
];

describe('SelectActionForm', () => {
    it('starts with the default label/variant and an enabled button (not gated on a selection) until something is selected', () => {
        render(
            <SelectActionForm
                options={OPTIONS}
                placeholderLabel="Choose..."
                defaultButtonLabel="Phew 😅"
                activeButtonLabel="Do it 🥀"
                defaultVariant="btn-secondary"
                activeVariant="btn-danger"
                pending={false}
                onSubmit={vi.fn()}
            />,
        );

        const button = screen.getByRole('button', { name: 'Phew 😅' });
        expect(button).not.toBeDisabled();
        // .btn-secondary/.btn-danger are pure CSS modifiers (background/border/color only) that
        // rely on the base .btn class for layout/shape/typography — omitting "btn" renders an
        // unstyled browser-default button. Regression test for that exact bug.
        expect(button.className).toBe('btn btn-secondary');
    });

    it('swaps the label and variant once a non-placeholder value is selected (suicide.js behavior)', () => {
        render(
            <SelectActionForm
                options={OPTIONS}
                placeholderLabel="Choose..."
                defaultButtonLabel="Phew 😅"
                activeButtonLabel="Do it 🥀"
                defaultVariant="btn-secondary"
                activeVariant="btn-danger"
                pending={false}
                onSubmit={vi.fn()}
            />,
        );

        fireEvent.change(screen.getByRole('combobox'), { target: { value: 'yes' } });

        const button = screen.getByRole('button', { name: 'Do it 🥀' });
        expect(button).not.toBeDisabled();
        expect(button.className).toBe('btn btn-danger');
    });

    it('supports a function form of activeButtonLabel keyed off the selected value (shop.js/inn behavior)', () => {
        render(
            <SelectActionForm
                options={[
                    { value: '1', label: 'Pick 🍺 Spiced Ale' },
                    { value: '2', label: 'Pick 🍎 Forest Apple' },
                ]}
                placeholderLabel="🚪 Home Town"
                defaultButtonLabel="Return"
                activeButtonLabel={value => `🪙 Order (${value})`}
                pending={false}
                onSubmit={vi.fn()}
            />,
        );

        fireEvent.change(screen.getByRole('combobox'), { target: { value: '2' } });
        expect(screen.getByRole('button', { name: '🪙 Order (2)' })).toBeInTheDocument();
    });

    it('reverts to the default label/variant when the placeholder is reselected', () => {
        render(
            <SelectActionForm
                options={OPTIONS}
                placeholderLabel="Choose..."
                defaultButtonLabel="Return"
                activeButtonLabel="🪙 Purchase"
                pending={false}
                onSubmit={vi.fn()}
            />,
        );

        const select = screen.getByRole('combobox');
        fireEvent.change(select, { target: { value: 'yes' } });
        expect(screen.getByRole('button', { name: '🪙 Purchase' })).toBeInTheDocument();

        fireEvent.change(select, { target: { value: '' } });
        expect(screen.getByRole('button', { name: 'Return' })).not.toBeDisabled();
    });

    it('calls onSubmit with the selected value on form submit', () => {
        const onSubmit = vi.fn();
        render(
            <SelectActionForm
                options={OPTIONS}
                placeholderLabel="Choose..."
                defaultButtonLabel="Return"
                activeButtonLabel="🪙 Purchase"
                pending={false}
                onSubmit={onSubmit}
            />,
        );

        fireEvent.change(screen.getByRole('combobox'), { target: { value: 'no' } });
        fireEvent.click(screen.getByRole('button', { name: '🪙 Purchase' }));

        expect(onSubmit).toHaveBeenCalledWith('no');
    });

    it('disables the button while pending, even with a selection made', () => {
        render(
            <SelectActionForm
                options={OPTIONS}
                placeholderLabel="Choose..."
                defaultButtonLabel="Return"
                activeButtonLabel="🪙 Purchase"
                pending={true}
                onSubmit={vi.fn()}
            />,
        );

        fireEvent.change(screen.getByRole('combobox'), { target: { value: 'no' } });
        expect(screen.getByRole('button', { name: '🪙 Purchase' })).toBeDisabled();
    });

    it('noPlaceholder mode degrades to an empty selection when there are no options to pre-select', () => {
        const onSubmit = vi.fn();
        render(
            <SelectActionForm
                noPlaceholder
                options={[]}
                defaultButtonLabel="Return"
                activeButtonLabel="Do it 🥀"
                pending={false}
                onSubmit={onSubmit}
            />,
        );

        expect((screen.getByRole('combobox') as HTMLSelectElement).value).toBe('');

        fireEvent.click(screen.getByRole('button', { name: 'Return' }));
        expect(onSubmit).toHaveBeenCalledWith('');
    });

    // Belt-and-braces alongside the `disabled` attribute: a form can still be submitted while
    // pending (Enter in the <select>, or a programmatic submit), and a second in-flight purchase
    // must never reach the server.
    it('ignores a submit that lands while pending, even if the disabled button is bypassed', () => {
        const onSubmit = vi.fn();
        const { container } = render(
            <SelectActionForm
                options={OPTIONS}
                placeholderLabel="Choose..."
                defaultButtonLabel="Return"
                activeButtonLabel="🪙 Purchase"
                pending={true}
                onSubmit={onSubmit}
            />,
        );

        fireEvent.change(screen.getByRole('combobox'), { target: { value: 'yes' } });
        fireEvent.submit(container.querySelector('form') as HTMLFormElement);

        expect(onSubmit).not.toHaveBeenCalled();
    });

    it('marks individual options disabled (e.g. an already-owned item)', () => {
        render(
            <SelectActionForm
                options={[
                    { value: '1', label: 'Pick 🗡️ Elven Needle (Owned)', disabled: true },
                    { value: '2', label: 'Pick ⚡ Stormbringer' },
                ]}
                placeholderLabel="🚪 Home Town"
                defaultButtonLabel="Return"
                activeButtonLabel="🪙 Purchase"
                pending={false}
                onSubmit={vi.fn()}
            />,
        );

        const owned = screen.getByRole('option', { name: 'Pick 🗡️ Elven Needle (Owned)' }) as HTMLOptionElement;
        expect(owned.disabled).toBe(true);
    });

    it('submitting with the placeholder still selected calls onSubmit with an empty string (old dual-purpose select-and-submit "go home" signal)', () => {
        const onSubmit = vi.fn();
        render(
            <SelectActionForm
                options={OPTIONS}
                placeholderLabel="🚪 Home Town"
                defaultButtonLabel="Return"
                activeButtonLabel="🪙 Purchase"
                pending={false}
                onSubmit={onSubmit}
            />,
        );

        fireEvent.click(screen.getByRole('button', { name: 'Return' }));

        expect(onSubmit).toHaveBeenCalledWith('');
    });

    it('noPlaceholder mode omits the synthetic placeholder option and pre-selects the first real option on mount, but keeps the default button label/variant until an explicit change (suicide.js: the "change" event never fires just from the browser default-selecting the first option)', () => {
        render(
            <SelectActionForm
                noPlaceholder
                options={OPTIONS}
                placeholderLabel="unused"
                defaultButtonLabel="Return"
                activeButtonLabel={value => (value === 'yes' ? 'Do it 🥀' : 'Phew 😅')}
                defaultVariant="btn-secondary"
                activeVariant={value => (value === 'yes' ? 'btn-danger' : 'btn-secondary')}
                pending={false}
                onSubmit={vi.fn()}
            />,
        );

        expect(screen.queryByRole('option', { name: 'unused' })).not.toBeInTheDocument();

        const select = screen.getByRole('combobox') as HTMLSelectElement;
        expect(select.value).toBe(OPTIONS[0].value);

        const button = screen.getByRole('button', { name: 'Return' });
        expect(button).not.toBeDisabled();
        expect(button.className).toBe('btn btn-secondary');
    });

    it('noPlaceholder mode applies the active label/variant once the user explicitly changes the selection', () => {
        render(
            <SelectActionForm
                noPlaceholder
                options={OPTIONS}
                placeholderLabel="unused"
                defaultButtonLabel="Return"
                activeButtonLabel={value => (value === 'yes' ? 'Do it 🥀' : 'Phew 😅')}
                defaultVariant="btn-secondary"
                activeVariant={value => (value === 'yes' ? 'btn-danger' : 'btn-secondary')}
                pending={false}
                onSubmit={vi.fn()}
            />,
        );

        fireEvent.change(screen.getByRole('combobox'), { target: { value: 'yes' } });
        const dangerButton = screen.getByRole('button', { name: 'Do it 🥀' });
        expect(dangerButton.className).toBe('btn btn-danger');

        // Explicitly re-selecting the already-pre-filled first option ('no') still counts as an
        // interaction — this is a real, submittable choice in noPlaceholder mode, unlike the
        // placeholder mode's empty-string "nothing chosen" sentinel.
        fireEvent.change(screen.getByRole('combobox'), { target: { value: 'no' } });
        const secondaryButton = screen.getByRole('button', { name: 'Phew 😅' });
        expect(secondaryButton.className).toBe('btn btn-secondary');
    });

    it('noPlaceholder mode submits the pre-selected first option without requiring any change (the button still reads its default label at that point)', () => {
        const onSubmit = vi.fn();
        render(
            <SelectActionForm
                noPlaceholder
                options={OPTIONS}
                placeholderLabel="unused"
                defaultButtonLabel="Return"
                activeButtonLabel="Do it 🥀"
                pending={false}
                onSubmit={onSubmit}
            />,
        );

        fireEvent.click(screen.getByRole('button', { name: 'Return' }));

        expect(onSubmit).toHaveBeenCalledWith(OPTIONS[0].value);
    });
});
