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
 * One component replacing five near-identical select+relabelling-button forms. All shared the
 * same mechanism — a `<select>` driving a companion button's label and (everywhere but Home) its
 * CSS variant — with different copy.
 *
 * Submitting with the placeholder still selected is a legitimate "go home" signal (`onSubmit('')`),
 * so the button is only ever disabled while `pending`.
 *
 * In `noPlaceholder` mode the button must still read `defaultButtonLabel` on first mount even
 * though `selected` already holds the pre-filled first option — the old scripts only relabelled
 * on an explicit `change` event, never on the browser's default selection. Hence `hasInteracted`
 * is tracked separately from the select's value.
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
