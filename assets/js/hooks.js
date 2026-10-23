// Every hook the game registers, one file each under hooks/. `app.js` reads this and nothing else,
// so a hook that is not listed here does not run.
import { AnimatedValues, shortFigure, percentFigure, tenthsFigure } from './hooks/animated-values';
import { DevKeys } from './hooks/dev-keys';
import { EffectTimers, timerLabel, remainingLabel } from './hooks/effect-timers';
import { Panel } from './hooks/panel';
import { PanelFocus } from './hooks/panel-focus';
import { SelectAction } from './hooks/select-action';
import { SoundToggle } from './hooks/sound-toggle';
import { Stamp, stampLabel } from './hooks/stamp';
import { Table } from './hooks/table';

// The client-side twins of `Format.short`, `Format.percent`, `Format.tenths`, `Format.countdown`,
// `Format.remaining` and `Format.stamp`, held to the server's own tables.
export { shortFigure, percentFigure, tenthsFigure, timerLabel, remainingLabel, stampLabel };

export const hooks = {
    PanelFocus, AnimatedValues, DevKeys, EffectTimers, Panel, SelectAction, SoundToggle, Stamp, Table,
};
