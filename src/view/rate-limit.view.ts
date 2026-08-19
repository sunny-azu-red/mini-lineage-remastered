import { readTemplate, render } from './base.view';
import { renderSimplePage } from './layout.view';
import { PlayerState } from '@/interface';

const rateLimitTpl = readTemplate('rate-limit.ejs');

export function renderRateLimitView(player: PlayerState | null, message: string, retryUrl: string): string {
    const content = render(rateLimitTpl, { message, retryUrl });

    return renderSimplePage('Slow down adventurer', content, null, player);
}
