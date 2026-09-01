import { useState, type FormEvent, type MouseEvent } from 'react';
import { useGameStore, type ScreenId } from '@/store/gameStore';
import { useAction } from '@/socket/useAction';
import { playSound } from '@/audio/soundfx';

// Races render as a plain <select> defaulting to the first option — there is no "nothing chosen"
// state to guard. The name-length check is a UX nicety only; the server schema is authoritative.
export default function GameStartScreen() {
    const catalog = useGameStore(state => state.catalog);
    const navigate = useGameStore(state => state.navigate);
    const applyMutation = useGameStore(state => state.applyMutation);
    const { run, pending } = useAction('game:start');

    const [name, setName] = useState('');
    const [raceId, setRaceId] = useState<number | null>(null);
    const [validationError, setValidationError] = useState<string | null>(null);

    if (!catalog)
        return null;

    // Destructured into locals: TypeScript's narrowing of `catalog` doesn't survive into the
    // hoisted function declarations below.
    const { nameMinLength, nameMaxLength, races } = catalog;
    const selectedRaceId = raceId ?? races[0]?.id ?? 0;

    const goTo = (screen: ScreenId) => (e: MouseEvent<HTMLAnchorElement>) => {
        e.preventDefault();
        navigate(screen);
    };

    function handleSubmit(e: FormEvent<HTMLFormElement>) {
        e.preventDefault();
        const trimmed = name.trim();

        if (trimmed.length < nameMinLength || trimmed.length > nameMaxLength) {
            setValidationError(`Your name must be between ${nameMinLength} and ${nameMaxLength} characters.`);
            return;
        }

        setValidationError(null);
        void run({ raceId: selectedRaceId, name: trimmed }, {
            onSuccess: data => {
                // One atomic update: navigate() first would pin against the still-unstarted store
                // player and bounce to 'start'; after would clear the welcome flash.
                applyMutation(data.player, data.flash, 'home');
                playSound(data.flash?.sound);
            },
        });
    }

    return (
        <>
            <h2>A New Bloodline Rises</h2>
            <p>
                Will you forge a fresh path, or honor the ancestors resting within the{' '}
                <a href="#highscores" onClick={goTo('highscores')}>Hall of Champions</a>?
                Blood, gold, and glory are etched in{' '}
                <a href="#statistics" onClick={goTo('statistics')}>The Tome of Lore</a>, while the{' '}
                <a href="#races" onClick={goTo('races')}>Chronicles of Ancestry</a> detail the unique traits of the
                lineages that walk this realm.
            </p>
            <p>Under what name shall the first chapter of your dynasty be written, and from which ancestry do you hail?</p>

            <form onSubmit={handleSubmit}>
                <div className="form-row">
                    <input
                        type="text"
                        className="form-input"
                        maxLength={nameMaxLength}
                        placeholder="Enter your name, Heir"
                        autoComplete="off"
                        required
                        value={name}
                        onChange={e => setName(e.target.value)}
                    />
                    <select className="form-select" value={selectedRaceId} onChange={e => setRaceId(Number(e.target.value))}>
                        {races.map(race => (
                            <option key={race.id} value={race.id}>{race.emoji} {race.label}</option>
                        ))}
                    </select>
                    <button type="submit" className="btn" disabled={pending}>🚩 Start</button>
                </div>
            </form>
            {validationError && <div className="alert alert-warning">{validationError}</div>}
        </>
    );
}
