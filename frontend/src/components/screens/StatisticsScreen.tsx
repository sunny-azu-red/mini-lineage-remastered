import { pluralize, fillTemplate, formatNumber, formatAdena } from '@shared/format';
import { useRequest } from '@/socket/useRequest';
import Narrative from '@/components/common/Narrative';
import BackLink from '@/components/common/BackLink';
import LoadingPanel from '@/components/common/LoadingPanel';

/**
 * "The Tome of Lore". The raw counters are fetched fresh; all the prose formatting that used to
 * happen server-side now happens here against `@shared/format`'s identical helpers.
 *
 * Templates embedding literal HTML go through `Narrative`; plain `pluralize` output is ordinary
 * text and is rendered as normal JSX children.
 */
interface CountedProps {
    /** Uses `{n}` for the pluralized count and `{isSingle}` for singular/plural verb agreement. */
    template: string;
    singular: string;
    plural: string;
    count: number;
}

function Counted({ template, singular, plural, count }: CountedProps) {
    return <Narrative html={fillTemplate(template, { n: pluralize(singular, plural, count), isSingle: count === 1 })} />;
}

/** A plain (markup-free) pluralized count, wrapped in a colour utility span. */
function Tally({ className, singular, plural, count }: { className: string; singular: string; plural: string; count: number }) {
    return <span className={className}>{pluralize(singular, plural, count)}</span>;
}

export default function StatisticsScreen() {
    const { data, loading } = useRequest('statistics:get', {});
    const stats = data?.stats;

    return (
        <>
            {/*
              * A failure surfaces as a notice banner (useRequest) and falls through to the
              * empty-archives copy — an empty database is a genuine, distinct condition from a
              * fetch that never came back, and the banner is what tells them apart. The BackLink
              * below sits OUTSIDE this branch so it stays reachable while loading.
              */}
            {loading && !data ? (
                <LoadingPanel label="Unsealing the tome…" />
            ) : stats ? (
                <>
                    <h2>The Legacy of the Realm</h2>
                    <p>
                        In the age of steel and magic,{' '}
                        <Counted
                            template='<span class="gold">{n}</span> {isSingle ? "has" : "have"} set foot upon these dangerous lands.'
                            singular="Brave Soul" plural="Brave Souls" count={stats.total_players}
                        />{' '}
                        Through hardship and triumph, they have collectively ascended{' '}
                        <Tally className="gold" singular="Level" plural="Levels" count={stats.total_levels_gained} /> in
                        their pursuit of power. Yet, glory always exacts a price, because{' '}
                        <Counted
                            template='<span class="hp">{n}</span> {isSingle ? "has" : "have"} fallen in battle... lost, but not forgotten.'
                            singular="Champion" plural="Champions" count={stats.total_deaths}
                        />
                    </p>
                    <p>
                        A few, overwhelmed by the weight of their journey, chose the coward&apos;s end, with{' '}
                        <Counted
                            template='<span class="muted">{n}</span> taking {isSingle ? "its own life" : "their own lives"},'
                            singular="Weak Soul" plural="Weak Souls" count={stats.total_players_suicided}
                        />{' '}
                        <Counted
                            template='while <span class="hp">{n}</span> {isSingle ? "was" : "were"} struck down by the gods for attempting to bypass the laws of the realm.'
                            singular="Heretic" plural="Heretics" count={stats.total_players_cheated}
                        />
                    </p>

                    <h2>Echoes of the Battlefield</h2>
                    <p>
                        The drums of war never truly fall silent because{' '}
                        <Counted
                            template='<span class="gold">{n}</span> {isSingle ? "has" : "have"} been fought against the encroaching darkness,'
                            singular="Battle" plural="Battles" count={stats.total_battles}
                        />{' '}
                        resulting in the defeat of{' '}
                        <Tally className="gold" singular="Formidable Foe" plural="Formidable Foes" count={stats.total_enemies_killed} />{' '}
                        through lethal precision and the{' '}
                        <Tally className="crit" singular="Critical Strike" plural="Critical Strikes" count={stats.total_critical_hits} />{' '}
                        that turned the tide of every skirmish.
                    </p>
                    <p>
                        From these conflicts, the survivors extracted vast wisdom, gaining a total of{' '}
                        <span className="xp">{formatNumber(stats.total_xp_gained)} XP</span>.{' '}
                        <Counted
                            template='But the wild is treacherous, as the hunters became the hunted and <span class="hp">{n}</span> {isSingle ? "has" : "have"} occurred, nearly claiming those who walked unprepared.'
                            singular="Ambush" plural="Ambushes" count={stats.total_ambushes}
                        />
                    </p>

                    <h2>The Toll of Survival</h2>
                    <p>
                        Hardship is measured in blood and resilience. Our champions have shed{' '}
                        <span className="hp">{formatNumber(stats.total_hp_lost)} HP</span>, flesh torn by tooth and
                        claw. Yet, the craft of the blacksmith has proven its worth, as armor deflected{' '}
                        <span className="muted">{formatNumber(stats.total_damage_blocked)} Damage</span>.
                    </p>
                    <p>
                        To mend their broken bodies, they have sought the warmth of the Inn and the delicious food
                        inside, healing for a combined total of{' '}
                        <span className="heal">{formatNumber(stats.total_hp_healed)} HP</span>. In the stillness of
                        sanctuary, where fine armor protects the weary, another{' '}
                        <span className="heal">{formatNumber(stats.total_hp_regen)} HP</span> was restored through
                        the natural mending of the soul.
                    </p>

                    <h2>The Flow of Fortune</h2>
                    <p>
                        Wealth flows like a river through the pockets of the daring. A massive sum of{' '}
                        <span className="gold">🪙 {formatAdena(stats.total_adena_generated)} Adena</span> has been
                        pulled from the corpses of monsters and the hidden corners of the world. Most of this
                        fortune, however, returns to the realm&apos;s economy since{' '}
                        <span className="gold">🪙 {formatAdena(stats.total_adena_spent)} Adena</span> has been spent
                        on provisions and equipment.
                    </p>
                    <p>
                        The shops have flourished, selling{' '}
                        <Tally className="gold" singular="Weapon" plural="Weapons" count={stats.total_weapons_bought} /> and{' '}
                        <Tally className="gold" singular="Armor" plural="Armors" count={stats.total_armors_bought} /> to
                        those who would be king, while the local Inn has served{' '}
                        <Tally className="gold" singular="Meal" plural="Meals" count={stats.total_food_bought} /> to keep
                        the fires of life burning.
                    </p>
                </>
            ) : (
                <p>
                    The ancient archives are empty and the lore of the realm has been lost to time. The chronicles
                    of the realm await their first dynasty. Will you be the one to start a new bloodline?
                </p>
            )}

            <BackLink label="Go back to game start" />
        </>
    );
}
