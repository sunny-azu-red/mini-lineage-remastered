import { z } from 'zod';

export const SocketPingEventSchema = z.object({
    timestamp: z.number().int().positive(),
});

export type SocketPingEventPayload = z.infer<typeof SocketPingEventSchema>;

export const SocketInputEventSchema = z.object({
    key: z.string().min(1).max(32),
});

export type SocketInputEventPayload = z.infer<typeof SocketInputEventSchema>;
