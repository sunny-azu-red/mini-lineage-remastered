import type { Ack, MutationResult, FlashView } from './common';
import type { PlayerSnapshot } from './player';
import type { GameCatalog } from './catalog';
import type { BattleFightResult } from './battle';
import type { HighscoreList, HighscoreSubmitResult } from './highscores';
import type { StatisticsResponse } from './statistics';

/**
 * Sent to the client on every socket connect AND reconnect. Building/sending this payload
 * must NEVER mutate player state — that invariant is what makes a hard refresh (even
 * mid-ambush) completely harmless. `player` is null when no character has been started yet.
 */
export interface HydratePayload {
    player: PlayerSnapshot | null;
    catalog: GameCatalog;
}

export type EmptyPayload = Record<string, never>;

export interface GameStartPayload {
    raceId: number;
    name: string;
}

export type ShopPurchasePayload =
    | { type: 'weapon'; itemId: number }
    | { type: 'armor'; itemId: number }
    | { type: 'food'; itemId: number };

export interface HighscoreListPayload {
    raceId?: number | null;
}

export interface InputPayload {
    key: string;
}

export interface ClientToServerEvents {
    'game:start': (p: GameStartPayload, ack: (r: Ack<MutationResult>) => void) => void;
    'game:restart': (p: EmptyPayload, ack: (r: Ack<{ hydrate: HydratePayload }>) => void) => void;
    'battle:fight': (p: EmptyPayload, ack: (r: Ack<BattleFightResult>) => void) => void;
    /**
     * Fired by the client whenever it navigates away from the Battle screen (see gameStore.ts's
     * navigate()) — the signal player.service.ts's syncZoneAuras needs to start the combat aura's
     * short regen-blocking grace period from the moment battle was actually left, instead of from
     * the last fight itself (which would let regen resume just by pausing between clicks while
     * still on the Battle screen).
     */
    'battle:leave': (p: EmptyPayload, ack: (r: Ack<MutationResult>) => void) => void;
    'shop:purchase': (p: ShopPurchasePayload, ack: (r: Ack<MutationResult>) => void) => void;
    'player:suicide': (p: EmptyPayload, ack: (r: Ack<MutationResult>) => void) => void;
    'highscores:submit': (p: EmptyPayload, ack: (r: Ack<HighscoreSubmitResult>) => void) => void;
    'highscores:list': (p: HighscoreListPayload, ack: (r: Ack<HighscoreList>) => void) => void;
    'statistics:get': (p: EmptyPayload, ack: (r: Ack<StatisticsResponse>) => void) => void;
    /** Fire-and-forget Konami-code relay — no ack, unchanged from today. */
    input: (p: InputPayload) => void;
}

export interface ServerToClientEvents {
    /** On connect AND every reconnect. Never a side effect of any mutation. */
    hydrate: (p: HydratePayload) => void;
    /** Tick regen, effect expiry, other-tab sync. Partial — client shallow-merges. */
    'state:update': (p: Partial<PlayerSnapshot>) => void;
    /** Server-initiated notice (e.g. Konami cheat activation). */
    notice: (p: FlashView) => void;
}
