import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { RACES, WEAPONS, ARMORS, FOODS } from '@/constant/game.constant';
import { simulateBattle } from '@/service/battle.service';
import { initializePlayer, resolveBattleOutcome, purchaseItem, getPlayerStats, processTick, syncZoneAuras } from '@/service/player.service';
import { calculateLevel, calculateAmbushChance } from '@/service/math.service';
import { buildBattleNarrative } from '@/service/narrative.service';
import { ItemType, type PlayerState } from '@/interface';

vi.mock('@/repository/statistics.repository', () => ({
    statisticsRepository: { increment: vi.fn().mockResolvedValue(undefined), getAll: vi.fn() },
}));

/**
 * GOLDEN MASTER for game balance.
 *
 * Plays 400 fights per character across all four races and five fixed RNG seeds, driving the
 * real battle math, stat pipeline, shop logic, level curve, ambush rolls and narrative draws —
 * then pins the resulting progression exactly. The expected values below were captured from the
 * pre-refactor code and verified bit-identical after it.
 *
 * Because every roll runs off one deterministic stream, this also pins the ORDER in which
 * Math.random() is consumed: adding, removing or reordering a draw anywhere in the fight path
 * shifts every later roll and fails here, even when each individual function is still correct.
 *
 * If you deliberately retune the game, regenerate these numbers in the same commit — a diff here
 * is exactly the balance change under review.
 */

// A small LCG, so the sequence is reproducible and independent of the JS engine.
let seed = 0;
const rng = () => (seed = (seed * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff;

function play(raceId: number, startSeed: number) {
    seed = startSeed;

    const player = {} as PlayerState;
    initializePlayer(player, RACES[raceId], `Hero${raceId}`);
    player.currentScreen = 'home';
    syncZoneAuras(player);

    for (let fight = 0; fight < 400 && !player.dead; fight++) {
        // Buy the best affordable weapon and armor, then eat if badly hurt.
        for (const [type, list] of [[ItemType.Weapon, WEAPONS], [ItemType.Armor, ARMORS]] as const) {
            const slot = type === ItemType.Weapon ? 'weaponId' : 'armorId';
            for (let id = list.length - 1; id >= 1; id--)
                if (player[slot] !== id && player.adena >= list[id].cost) {
                    purchaseItem(player, type, id);
                    break;
                }
        }
        if (player.health < getPlayerStats(player).maxHealth / 2)
            for (let id = FOODS.length - 1; id >= 0; id--)
                if (player.adena >= FOODS[id].cost) {
                    purchaseItem(player, ItemType.Food, id);
                    break;
                }

        player.currentScreen = 'battle';
        player.ambushed = false;
        syncZoneAuras(player);

        const result = simulateBattle(player);
        result.isLevelUp = resolveBattleOutcome(player, result);

        if (!player.dead) {
            const ambushed = calculateAmbushChance(getPlayerStats(player).ambushRisk);
            if (ambushed) {
                player.ambushed = true;
                player.totalAmbushes = (player.totalAmbushes ?? 0) + 1;
            }
            // Included because it consumes randomness — dropping it would shift the stream.
            buildBattleNarrative(player, result, ambushed);
        }

        processTick(player, { applyRegen: true });
    }

    return {
        level: calculateLevel(player.experience ?? 0),
        experience: player.experience,
        adena: player.adena,
        dead: Boolean(player.dead),
        battles: player.totalBattles,
        kills: player.totalEnemiesKilled,
        ambushes: player.totalAmbushes,
        weaponId: player.weaponId,
        armorId: player.armorId,
    };
}

const GOLDEN: Array<[string, ReturnType<typeof play>]> = [
    ["race0-seed1", {"level":21,"experience":60638,"adena":650,"dead":false,"battles":400,"kills":2664,"ambushes":13,"weaponId":1,"armorId":1}],
    ["race0-seed7", {"level":21,"experience":63968,"adena":199,"dead":false,"battles":400,"kills":2744,"ambushes":16,"weaponId":1,"armorId":1}],
    ["race0-seed42", {"level":21,"experience":61893,"adena":380,"dead":false,"battles":400,"kills":2689,"ambushes":9,"weaponId":1,"armorId":1}],
    ["race0-seed1234", {"level":21,"experience":60575,"adena":398,"dead":false,"battles":400,"kills":2700,"ambushes":19,"weaponId":1,"armorId":1}],
    ["race0-seed99999", {"level":21,"experience":62433,"adena":160,"dead":false,"battles":400,"kills":2751,"ambushes":20,"weaponId":1,"armorId":1}],
    ["race1-seed1", {"level":20,"experience":57062,"adena":300,"dead":false,"battles":400,"kills":2601,"ambushes":56,"weaponId":1,"armorId":1}],
    ["race1-seed7", {"level":20,"experience":55972,"adena":157,"dead":false,"battles":400,"kills":2564,"ambushes":42,"weaponId":1,"armorId":1}],
    ["race1-seed42", {"level":20,"experience":55627,"adena":560,"dead":false,"battles":400,"kills":2567,"ambushes":57,"weaponId":1,"armorId":1}],
    ["race1-seed1234", {"level":20,"experience":57063,"adena":400,"dead":false,"battles":400,"kills":2602,"ambushes":54,"weaponId":1,"armorId":1}],
    ["race1-seed99999", {"level":20,"experience":56957,"adena":178,"dead":false,"battles":400,"kills":2577,"ambushes":49,"weaponId":1,"armorId":1}],
    ["race2-seed1", {"level":22,"experience":67789,"adena":162,"dead":false,"battles":400,"kills":2842,"ambushes":0,"weaponId":1,"armorId":1}],
    ["race2-seed7", {"level":22,"experience":69763,"adena":481,"dead":false,"battles":400,"kills":2924,"ambushes":0,"weaponId":1,"armorId":1}],
    ["race2-seed42", {"level":22,"experience":66908,"adena":461,"dead":false,"battles":400,"kills":2843,"ambushes":0,"weaponId":1,"armorId":1}],
    ["race2-seed1234", {"level":22,"experience":69161,"adena":314,"dead":false,"battles":400,"kills":2831,"ambushes":0,"weaponId":1,"armorId":1}],
    ["race2-seed99999", {"level":22,"experience":66293,"adena":529,"dead":false,"battles":400,"kills":2829,"ambushes":0,"weaponId":1,"armorId":1}],
    ["race3-seed1", {"level":23,"experience":71882,"adena":200,"dead":false,"battles":400,"kills":2944,"ambushes":1,"weaponId":1,"armorId":1}],
    ["race3-seed7", {"level":23,"experience":72810,"adena":565,"dead":false,"battles":400,"kills":2984,"ambushes":2,"weaponId":1,"armorId":1}],
    ["race3-seed42", {"level":22,"experience":66765,"adena":788,"dead":false,"battles":400,"kills":2809,"ambushes":4,"weaponId":1,"armorId":1}],
    ["race3-seed1234", {"level":23,"experience":72971,"adena":871,"dead":false,"battles":400,"kills":2954,"ambushes":3,"weaponId":1,"armorId":1}],
    ["race3-seed99999", {"level":22,"experience":69425,"adena":272,"dead":false,"battles":400,"kills":2857,"ambushes":3,"weaponId":1,"armorId":1}],
];

describe('game balance golden master', () => {
    beforeEach(() => vi.spyOn(Math, 'random').mockImplementation(rng));
    afterEach(() => vi.restoreAllMocks());

    it.each(GOLDEN)('%s plays out exactly as before', (key, expected) => {
        const [, raceId, startSeed] = key.match(/^race(\d+)-seed(\d+)$/)!.map(Number) as [never, number, number];

        expect(play(raceId, startSeed)).toEqual(expected);
    });
});
