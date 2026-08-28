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

    it('noPlaceholder mode omits the synthetic placeholder option and pre-selects the first real option on mount', () => {
        render(
            <SelectActionForm
                noPlaceholder
                options={OPTIONS}
                placeholderLabel="unused"
                defaultButtonLabel="Return"
                activeButtonLabel={value => (value === 'yes' ? 'Do it 🥀' : 'Phew 😅')}
                activeVariant={value => (value === 'yes' ? 'btn-danger' : 'btn-secondary')}
                pending={false}
                onSubmit={vi.fn()}
            />,
        );

        expect(screen.queryByRole('option', { name: 'unused' })).not.toBeInTheDocument();

        const select = screen.getByRole('combobox') as HTMLSelectElement;
        expect(select.value).toBe(OPTIONS[0].value);
        expect(screen.getByRole('button', { name: 'Do it 🥀' })).toBeInTheDocument();
    });

    it('noPlaceholder mode submits the pre-selected first option without requiring any change', () => {
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

        fireEvent.click(screen.getByRole('button', { name: 'Do it 🥀' }));

        expect(onSubmit).toHaveBeenCalledWith(OPTIONS[0].value);
    });
});
