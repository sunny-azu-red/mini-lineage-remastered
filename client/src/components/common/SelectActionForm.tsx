import { useState, type FormEvent } from 'react';

export type ButtonVariant = 'btn' | 'btn-secondary' | 'btn-danger';

export interface SelectActionOption {
    value: string;
    label: string;
    disabled?: boolean;
}

interface SelectActionFormProps {
    options: SelectActionOption[];
    /** The <select>'s initial/no-selection option text. */
    placeholderLabel: string;
    defaultButtonLabel: string;
    activeButtonLabel: string | ((selectedValue: string) => string);
    defaultVariant?: ButtonVariant;
    /**
     * A single variant, OR a function of the selected value — needed to faithfully port
     * suicide.js, whose two non-default choices ('yes'/'no') each carry their OWN variant
     * (btn-danger / btn-secondary respectively), not just one "active" variant vs. one default.
     */
    activeVariant?: ButtonVariant | ((selectedValue: string) => ButtonVariant);
    pending: boolean;
    onSubmit: (value: string) => void;
}

/**
 * One reusable component replacing FIVE near-identical select+button-relabel templates/scripts
 * (home.ejs+home.js, inn.ejs+shop.js, weapons/armors-shop.ejs+shop.js, suicide.ejs+suicide.js).
 * All five shared the same mechanism — a `<select>` whose value drives a companion `<button>`'s
 * label and (for shop/inn/suicide, not home) CSS variant — even though the exact copy differed
 * between them:
 *
 *   - home.js: label swaps ('Travel' -> '⚰️ Perish' when the suicide destination is picked),
 *     variant never changes (always plain `.btn`), and the button is never disabled — a
 *     destination is always pre-selected (there's no "nothing picked" state on that page).
 *   - shop.js: label swaps ('Return' -> e.g. '🪙 Purchase'/'🪙 Order') AND variant swaps
 *     (`.btn-secondary` -> `.btn`) together, gated on the placeholder ('') option.
 *   - suicide.js: label swaps ('Phew 😅' -> 'Do it 🥀') AND variant swaps (`.btn-secondary` ->
 *     `.btn-danger`) together — no placeholder option; the default choice ("no") IS a real,
 *     submittable value.
 *
 * This component generalizes all three shapes: `activeButtonLabel`/`activeVariant` only apply
 * once something other than the placeholder option is selected, and until then the button shows
 * `defaultButtonLabel`/`defaultVariant` and is `disabled` (this is the one deliberate behavior
 * change from home.js, which never disabled its button — see HomeScreen's own doc comment for
 * why that's an intentional simplification worth taking here, not a regression).
 */
export default function SelectActionForm({
    options,
    placeholderLabel,
    defaultButtonLabel,
    activeButtonLabel,
    defaultVariant = 'btn-secondary',
    activeVariant = 'btn',
    pending,
    onSubmit,
}: SelectActionFormProps) {
    const [selected, setSelected] = useState('');
    const hasSelection = selected !== '';

    const buttonLabel = hasSelection
        ? typeof activeButtonLabel === 'function'
            ? activeButtonLabel(selected)
            : activeButtonLabel
        : defaultButtonLabel;
    const buttonVariant = hasSelection
        ? typeof activeVariant === 'function'
            ? activeVariant(selected)
            : activeVariant
        : defaultVariant;

    function handleSubmit(e: FormEvent<HTMLFormElement>) {
        e.preventDefault();
        if (!hasSelection || pending)
            return;

        onSubmit(selected);
    }

    return (
        <form onSubmit={handleSubmit}>
            <div className="form-row">
                <select
                    className="form-select"
                    value={selected}
                    onChange={e => setSelected(e.target.value)}
                >
                    <option value="">{placeholderLabel}</option>
                    {options.map(opt => (
                        <option key={opt.value} value={opt.value} disabled={opt.disabled}>
                            {opt.label}
                        </option>
                    ))}
                </select>
                <button type="submit" className={buttonVariant} disabled={!hasSelection || pending}>
                    {buttonLabel}
                </button>
            </div>
        </form>
    );
}
