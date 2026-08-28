import { useGameStore } from '@/store/gameStore';
import { useAction } from '@/socket/useAction';
import { playSound } from '@/audio/soundfx';
import SelectActionForm from '@/components/common/SelectActionForm';

// Ported from suicide.ejs + suicide.js. suicide.js's two non-default choices each carry a
// DIFFERENT variant ('yes' -> btn-danger, 'no' -> btn-secondary) — SelectActionForm's function
// form of `activeVariant` (added specifically to support this screen faithfully) expresses that.
export default function SuicideScreen() {
    const navigate = useGameStore(state => state.navigate);
    const applyMutation = useGameStore(state => state.applyMutation);
    const { run, pending } = useAction('player:suicide');

    function handleSubmit(value: string) {
        if (value !== 'yes') {
            navigate('home');
            return;
        }

        void run(
            {},
            {
                onSuccess: data => {
                    applyMutation(data.player, data.flash);
                    playSound('death');
                    navigate('death');
                },
            },
        );
    }

    return (
        <>
            <p>Do you wish to depart this world?</p>
            <SelectActionForm
                options={[
                    { value: 'no', label: 'No, I changed my mind' },
                    { value: 'yes', label: 'Yes, stab yourself in the heart' },
                ]}
                noPlaceholder
                defaultButtonLabel="Return"
                activeButtonLabel={value => (value === 'yes' ? 'Do it 🥀' : 'Phew 😅')}
                defaultVariant="btn-secondary"
                activeVariant={value => (value === 'yes' ? 'btn-danger' : 'btn-secondary')}
                pending={pending}
                onSubmit={handleSubmit}
            />
        </>
    );
}
