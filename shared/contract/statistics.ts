/** Raw counters (see src/constant/statistics.constant.ts::ALL_STAT_FIELDS); null when total_players === 0. */
export interface StatisticsResponse {
    stats: Record<string, number> | null;
}
