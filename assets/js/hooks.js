// Every hook the game registers, one file each under hooks/. `app.js` reads this and nothing else,
// so a hook that is not listed here does not run.
import { AnimatedValues, shortAdena } from './hooks/animated-values';
import { EffectTimers, timerLabel, remainingLabel } from './hooks/effect-timers';
import { KonamiRelay } from './hooks/konami-relay';
import { LocalTimes } from './hooks/local-times';
import { Panel } from './hooks/panel';
import { PanelFocus } from './hooks/panel-focus';
import { SoundToggle } from './hooks/sound-toggle';

// The client-side twins of `Format`, which the suites hold to the server's own tables.
export { shortAdena, timerLabel, remainingLabel };

export const hooks = {
    SoundToggle, EffectTimers, KonamiRelay, PanelFocus, AnimatedValues, Panel, LocalTimes,
};
