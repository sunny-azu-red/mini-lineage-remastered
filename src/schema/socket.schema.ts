import { z } from 'zod';

export const SocketInputEventSchema = z.object({
    key: z.string().min(1).max(32),
});

export type SocketInputEventPayload = z.infer<typeof SocketInputEventSchema>;
