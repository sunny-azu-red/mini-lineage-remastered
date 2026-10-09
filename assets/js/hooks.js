// Every hook the game registers, one file each under hooks/. `app.js` reads this and nothing else,
// so a hook that is not listed here does not run.
import { AnimatedValues, shortFigure } from './hooks/animated-values';
import { Panel } from './hooks/panel';
import { PanelFocus } from './hooks/panel-focus';
import { SoundToggle } from './hooks/sound-toggle';

// The client-side twin of `Format.short`, which the suites hold to the server's own table.
export { shortFigure };

export const hooks = { PanelFocus, AnimatedValues, Panel, SoundToggle };
