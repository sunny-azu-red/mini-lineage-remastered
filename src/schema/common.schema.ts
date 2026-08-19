import { z } from 'zod';

/**
 * A shared helper to validate string IDs from form inputs, 
 * transform them to numbers, and check them against a whitelist.
 */
export const itemIdSchema = (validIds: number[]) =>
    z.string().transform((val, ctx) => {
        const n = parseInt(val, 10);
        if (isNaN(n) || !validIds.includes(n)) {
            ctx.addIssue({ code: z.ZodIssueCode.custom, message: 'Invalid ID' });
            return z.NEVER;
        }

        return n;
    });
