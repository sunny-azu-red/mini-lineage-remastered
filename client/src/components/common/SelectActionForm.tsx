import { useState, type FormEvent } from 'react';

export type ButtonVariant = 'btn' | 'btn-secondary' | 'btn-danger';

export interface SelectActionOption {
    value: string;
    label: string;
    disabled?: boolean;
}

interface SelectActionFormProps {
    options: SelectActionOption[];
    /**
     * The <select>'s initial/no-selection option text. Ignored (and may be omitted) when
     * `noPlaceholder` is set, since no such option is rendered in that mode.
     */
    placeholderLabel?: string;
    /**
     * When true, skips rendering the synthetic placeholder `<option>` entirely and pre-selects
     * the first real option on mount — for screens (Suicide) whose old template never had a
     * "nothing picked" state to begin with.
     */
    noPlaceholder?: boolean;
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
 * `defaultButtonLabel`/`defaultVariant`. The button is only ever `disabled` while `pending` —
 * matching every old page's actual behavior, including shop.js/inn: submitting with the
 * placeholder still selected is a legitimate "go home" signal (`onSubmit('')`), exactly like the
 * old dual-purpose select-and-submit forms. `noPlaceholder` mode (Suicide) skips the synthetic
 * placeholder option altogether and pre-selects the first real option on mount, matching
 * suicide.ejs's natural default-selected-first-option behavior.
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
        if (pending)
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
                    {!noPlaceholder && <option value="">{placeholderLabel}</option>}
                    {options.map(opt => (
                        <option key={opt.value} value={opt.value} disabled={opt.disabled}>
                            {opt.label}
                        </option>
                    ))}
                </select>
                <button type="submit" className={buttonVariant} disabled={pending}>
                    {buttonLabel}
                </button>
            </div>
        </form>
    );
}
