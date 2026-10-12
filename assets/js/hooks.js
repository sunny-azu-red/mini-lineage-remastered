// Every hook the game registers, one file each under hooks/. `app.js` reads this and nothing else,
// so a hook that is not listed here does not run.
import { AnimatedValues, shortFigure, percentFigure, tenthsFigure } from './hooks/animated-values';
import { DevKeys } from './hooks/dev-keys';
import { Panel } from './hooks/panel';
import { PanelFocus } from './hooks/panel-focus';
import { SelectAction } from './hooks/select-action';
import { SoundToggle } from './hooks/sound-toggle';
import { Table } from './hooks/table';

// The client-side twins of `Format.short`, `Format.percent` and `Format.tenths`, held to the server's
// own tables.
export { shortFigure, percentFigure, tenthsFigure };

export const hooks = { PanelFocus, AnimatedValues, DevKeys, Panel, SelectAction, SoundToggle, Table };
