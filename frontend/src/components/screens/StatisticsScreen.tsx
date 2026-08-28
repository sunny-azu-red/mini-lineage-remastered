import { useEffect, useState, type MouseEvent } from 'react';
import { pluralize, fillTemplate, formatNumber, formatAdena } from '@shared/format';
import { useGameStore } from '@/store/gameStore';
import { request } from '@/socket/client';
import Narrative from '@/components/common/Narrative';

/**
 * Ported from statistics.ejs + statistics.view.ts's renderStatisticsView — "The Tome of Lore".
 * The raw counters (`Record<string, number>`, see src/constant/statistics.constant.ts's
 * ALL_STAT_FIELDS) are fetched fresh here; all the narrative prose/formatting that used to happen
 * server-side (fillTemplate/pluralize + formatNumber/formatAdena) now happens client-side against
 * `@shared/format`'s ports of the exact same functions.
 *
 * `fillTemplate(...)` calls embed literal HTML (`<span class="...">`) in their template string —
 * those go through `Narrative` (plan decision A12). Plain `pluralize(...)` calls return plain
 * text with no markup, so they're rendered as ordinary JSX children wrapped in a literal
 * `<span>` here (mirroring the ejs template's own literal `<span class="gold"><%- pluralize(...) %></span>`
 * markup) — no `dangerouslySetInnerHTML` needed for those.
 */
export default function StatisticsScreen() {
    const player = useGameStore(state => state.player);
    const navigate = useGameStore(state => state.navigate);
    const [stats, setStats] = useState<Record<string, number> | null | undefined>(undefined);

    useEffect(() => {
        let cancelled = false;

        void request('statistics:get', {}).then(res => {
            if (cancelled)
                return;

            setStats(res.ok ? res.data.stats : null);
        });

        return () => {
            cancelled = true;
        };
    }, []);

    function handleBack(e: MouseEvent<HTMLAnchorElement>) {
        e.preventDefault();
        navigate(player?.started ? 'home' : 'start');
    }

    if (stats === undefined)
        return null;

    return (
        <>
            {stats ? (
                <>
                    <h2>The Legacy of the Realm</h2>
                    <p>
                        In the age of steel and magic,{' '}
                        <Narrative
                            html={fillTemplate(
                                '<span class="gold">{playerText}</span> {isSinglePlayer ? "has" : "have"} set foot upon these dangerous lands.',
                                {
                                    playerText: pluralize('Brave Soul', 'Brave Souls', stats.total_players),
                                    isSinglePlayer: stats.total_players === 1,
                                },
                            )}
                        />{' '}
                        Through hardship and triumph, they have collectively ascended{' '}
                        <span className="gold">{pluralize('Level', 'Levels', stats.total_levels_gained)}</span> in
                        their pursuit of power. Yet, glory always exacts a price, because{' '}
                        <Narrative
                            html={fillTemplate(
                                '<span class="hp">{deathText}</span> {isSingleDeath ? "has" : "have"} fallen in battle... lost, but not forgotten.',
                                {
                                    deathText: pluralize('Champion', 'Champions', stats.total_deaths),
                                    isSingleDeath: stats.total_deaths === 1,
                                },
                            )}
                        />
                    </p>
                    <p>
                        A few, overwhelmed by the weight of their journey, chose the coward&apos;s end, with{' '}
                        <Narrative
                            html={fillTemplate(
                                '<span class="muted">{suicideText}</span> taking {isSingleSuicide ? "its own life" : "their own lives"},',
                                {
                                    suicideText: pluralize('Weak Soul', 'Weak Souls', stats.total_players_suicided),
                                    isSingleSuicide: stats.total_players_suicided === 1,
                                },
                            )}
                        />{' '}
                        <Narrative
                            html={fillTemplate(
                                'while <span class="hp">{cheatText}</span> {isSingleCheat ? "was" : "were"} struck down by the gods for attempting to bypass the laws of the realm.',
                                {
                                    cheatText: pluralize('Heretic', 'Heretics', stats.total_players_cheated),
                                    isSingleCheat: stats.total_players_cheated === 1,
                                },
                            )}
                        />
                    </p>

                    <h2>Echoes of the Battlefield</h2>
                    <p>
                        The drums of war never truly fall silent because{' '}
                        <Narrative
                            html={fillTemplate(
                                '<span class="gold">{battleText}</span> {isSingleBattle ? "has" : "have"} been fought against the encroaching darkness,',
                                {
                                    battleText: pluralize('Battle', 'Battles', stats.total_battles),
                                    isSingleBattle: stats.total_battles === 1,
                                },
                            )}
                        />{' '}
                        resulting in the defeat of{' '}
                        <span className="gold">{pluralize('Formidable Foe', 'Formidable Foes', stats.total_enemies_killed)}</span>{' '}
                        through lethal precision and the{' '}
                        <span className="crit">{pluralize('Critical Strike', 'Critical Strikes', stats.total_critical_hits)}</span>{' '}
                        that turned the tide of every skirmish.
                    </p>
                    <p>
                        From these conflicts, the survivors extracted vast wisdom, gaining a total of{' '}
                        <span className="xp">{formatNumber(stats.total_xp_gained)} XP</span>.{' '}
                        <Narrative
                            html={fillTemplate(
                                'But the wild is treacherous, as the hunters became the hunted and <span class="hp">{ambushText}</span> {isSingleAmbush ? \'has\' : \'have\'} occurred, nearly claiming those who walked unprepared.',
                                {
                                    ambushText: pluralize('Ambush', 'Ambushes', stats.total_ambushes),
                                    isSingleAmbush: stats.total_ambushes === 1,
                                },
                            )}
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
                        <span className="gold">{pluralize('Weapon', 'Weapons', stats.total_weapons_bought)}</span> and{' '}
                        <span className="gold">{pluralize('Armor', 'Armors', stats.total_armors_bought)}</span> to
                        those who would be king, while the local Inn has served{' '}
                        <span className="gold">{pluralize('Meal', 'Meals', stats.total_food_bought)}</span> to keep
                        the fires of life burning.
                    </p>
                </>
            ) : (
                <p>
                    The ancient archives are empty and the lore of the realm has been lost to time. The chronicles
                    of the realm await their first dynasty. Will you be the one to start a new bloodline?
                </p>
            )}

            <p className="last back">
                <a href="#home" onClick={handleBack}>
                    Go back to game start
                </a>
            </p>
        </>
    );
}
