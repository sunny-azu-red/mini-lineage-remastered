import { useState, type FormEvent } from 'react';

export type ButtonVariant = 'btn' | 'btn-secondary' | 'btn-danger';

export interface SelectActionOption {
    value: string;
    label: string;
    disabled?: boolean;
}

interface SelectActionFormProps {
    options: SelectActionOption[];
    /** The no-selection option's text. Ignored (and omittable) when `noPlaceholder` is set. */
    placeholderLabel?: string;
    /** Skips the synthetic placeholder and pre-selects the first real option (Home, Suicide). */
    noPlaceholder?: boolean;
    defaultButtonLabel: string;
    activeButtonLabel: string | ((selectedValue: string) => string);
    defaultVariant?: ButtonVariant;
    /** A function form is needed for Suicide, whose two choices each carry their own variant. */
    activeVariant?: ButtonVariant | ((selectedValue: string) => ButtonVariant);
    pending: boolean;
    onSubmit: (value: string) => void;
}

const resolve = <T,>(value: T | ((selected: string) => T), selected: string): T =>
    typeof value === 'function' ? (value as (s: string) => T)(selected) : value;

/**
 * One shared form for a `<select>` driving a companion button's label (and usually its CSS
 * variant). Submitting with the placeholder still selected is a legitimate "go home" signal
 * (`onSubmit('')`), so the button is only ever disabled while `pending`. In `noPlaceholder` mode,
 * `hasInteracted` is tracked separately from the select's value so the button still reads
 * `defaultButtonLabel` on first mount, before any explicit `change`.
 */
export default function SelectActionForm({
    options,
    placeholderLabel,
    noPlaceholder = false,
    defaultButtonLabel,
    activeButtonLabel,
    defaultVariant = 'btn-secondary',
    activeVariant = 'btn',
    pending,
    onSubmit,
}: SelectActionFormProps) {
    const [selected, setSelected] = useState(noPlaceholder ? options[0]?.value ?? '' : '');
    const [hasInteracted, setHasInteracted] = useState(false);
    const hasSelection = noPlaceholder ? hasInteracted : selected !== '';

    const label = hasSelection ? resolve(activeButtonLabel, selected) : defaultButtonLabel;
    const variant = hasSelection ? resolve(activeVariant, selected) : defaultVariant;

    function handleSubmit(e: FormEvent<HTMLFormElement>) {
        e.preventDefault();
        if (!pending)
            onSubmit(selected);
    }

    return (
        <form onSubmit={handleSubmit}>
            <div className="form-row">
                <select
                    className="form-select"
                    value={selected}
                    onChange={e => {
                        setSelected(e.target.value);
                        setHasInteracted(true);
                    }}
                >
                    {!noPlaceholder && <option value="">{placeholderLabel}</option>}
                    {options.map(opt => (
                        <option key={opt.value} value={opt.value} disabled={opt.disabled}>{opt.label}</option>
                    ))}
                </select>
                <button type="submit" className={variant === 'btn' ? 'btn' : `btn ${variant}`} disabled={pending}>
                    {label}
                </button>
            </div>
        </form>
    );
}
