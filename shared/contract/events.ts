import type { Ack, MutationResult, FlashView, ScreenId } from './common';
import type { PlayerSnapshot } from './player';
import type { GameCatalog } from './catalog';
import type { BattleFightResult } from './battle';
import type { HighscoreList, HighscoreSubmitResult } from './highscores';
import type { StatisticsResponse } from './statistics';

/**
 * Sent on every connect AND reconnect. Building this payload must NEVER mutate player state —
 * that invariant is what makes a hard refresh, even mid-ambush, completely harmless.
 * `player` is null when no character has been started.
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

export interface PlayerScreenPayload {
    screen: ScreenId;
}

export interface ClientToServerEvents {
    'game:start': (p: GameStartPayload, ack: (r: Ack<MutationResult>) => void) => void;
    'game:restart': (p: EmptyPayload, ack: (r: Ack<{ hydrate: HydratePayload }>) => void) => void;
    'battle:fight': (p: EmptyPayload, ack: (r: Ack<BattleFightResult>) => void) => void;
    /**
     * Fired on every screen change so the server can classify combat/resting zones from
     * location alone. `ambushed` still forces combat server-side regardless of what is
     * reported here, so a raw client lying about its screen can never escape an ambush.
     */
    'player:screen': (p: PlayerScreenPayload, ack: (r: Ack<MutationResult>) => void) => void;
    'shop:purchase': (p: ShopPurchasePayload, ack: (r: Ack<MutationResult>) => void) => void;
    'player:suicide': (p: EmptyPayload, ack: (r: Ack<MutationResult>) => void) => void;
    'highscores:submit': (p: EmptyPayload, ack: (r: Ack<HighscoreSubmitResult>) => void) => void;
    'highscores:list': (p: HighscoreListPayload, ack: (r: Ack<HighscoreList>) => void) => void;
    'statistics:get': (p: EmptyPayload, ack: (r: Ack<StatisticsResponse>) => void) => void;
    /** Fire-and-forget Konami relay — no ack. */
    input: (p: InputPayload) => void;
}

export interface ServerToClientEvents {
    /** On connect AND every reconnect. Never a side effect of a mutation. */
    hydrate: (p: HydratePayload) => void;
    /** Tick regen, effect expiry, other-tab sync. Partial — the client shallow-merges. */
    'state:update': (p: Partial<PlayerSnapshot>) => void;
    /** Server-initiated notice (e.g. Konami activation). */
    notice: (p: FlashView) => void;
}
