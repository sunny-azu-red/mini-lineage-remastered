import { ALL_STAT_FIELDS } from '@/constant/statistics.constant';

export type StatField = (typeof ALL_STAT_FIELDS)[number];

export interface StatRow {
    name: StatField;
    value: number;
}

export type Statistics = {
    [K in StatField]: number;
};
