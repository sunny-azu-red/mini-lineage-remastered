import { useEffect, type ComponentType } from 'react';
import AppShell from './components/layout/AppShell';
import ErrorBoundary from './components/ErrorBoundary';
import { useGameStore, type ScreenId } from './store/gameStore';
import { useHistorySync } from './hooks/useHistorySync';
import { useKonamiRelay } from './hooks/useKonamiRelay';
import GameStartScreen from './components/screens/GameStartScreen';
import HomeScreen from './components/screens/HomeScreen';
import InnScreen from './components/screens/InnScreen';
import WeaponsShopScreen from './components/screens/WeaponsShopScreen';
import ArmorsShopScreen from './components/screens/ArmorsShopScreen';
import SuicideScreen from './components/screens/SuicideScreen';
import BattleScreen from './components/screens/BattleScreen';
import DeathScreen from './components/screens/DeathScreen';
import CharacterScreen from './components/screens/CharacterScreen';
import HighscoresScreen from './components/screens/HighscoresScreen';
import StatisticsScreen from './components/screens/StatisticsScreen';
import RacesScreen from './components/screens/RacesScreen';
import ErrorScreen from './components/screens/ErrorScreen';

const SCREENS: Record<ScreenId, ComponentType> = {
    start: GameStartScreen,
    home: HomeScreen,
    inn: InnScreen,
    weapons: WeaponsShopScreen,
    armors: ArmorsShopScreen,
    suicide: SuicideScreen,
    battle: BattleScreen,
    death: DeathScreen,
    character: CharacterScreen,
    highscores: HighscoresScreen,
    statistics: StatisticsScreen,
    races: RacesScreen,
    // Distinct from ErrorBoundary (which catches a truly unexpected render-time throw anywhere
    // in the tree, see that component's doc comment): this is the store's explicit `screen:
    // 'error'` case — an expected-but-unrecoverable condition the app navigated to on purpose.
    // No store field carries a message for that path today, so it renders with no `detail`.
    error: ErrorScreen,
};

// Exact old title strings, one per route, pulled verbatim from the pre-rewrite app's
// `renderPage(...)`/`renderSimplePage(...)` calls (git show 6256e28:src/view/{game,battle,shop,
// player,highscores,statistics,race}.view.ts) — the old app drove both the `<title>` tag and an
// in-panel heading off this one string per route. `error` has no old equivalent (that screen
// state didn't exist pre-rewrite) so it gets a sensible new title instead.
const SCREEN_TITLES: Record<ScreenId, string> = {
    start: 'Game Start',
    home: 'Home Town',
    inn: 'Inn',
    weapons: 'Weapons Shop',
    armors: 'Armor Shop',
    suicide: 'Commit Suicide',
    battle: 'Battleground',
    death: 'Game Over',
    character: 'Character',
    highscores: 'Hall of Champions',
    statistics: 'The Tome of Lore',
    races: 'Chronicles of Ancestry',
    error: 'Error',
};

export default function App() {
    const screen = useGameStore(state => state.screen);
    const Screen = SCREENS[screen];
    const title = SCREEN_TITLES[screen];

    useHistorySync();
    useKonamiRelay();

    useEffect(() => {
        document.title = `Mini Lineage - ${title}`;
    }, [title]);

    return (
        <ErrorBoundary>
            <AppShell title={title}>
                <Screen />
            </AppShell>
        </ErrorBoundary>
    );
}
