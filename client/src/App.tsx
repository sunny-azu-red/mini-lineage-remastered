import type { ComponentType } from 'react';
import AppShell from './components/layout/AppShell';
import ErrorBoundary from './components/ErrorBoundary';
import { useGameStore, type ScreenId } from './store/gameStore';
import { useHistorySync } from './hooks/useHistorySync';
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

export default function App() {
    const screen = useGameStore(state => state.screen);
    const Screen = SCREENS[screen];

    useHistorySync();

    return (
        <ErrorBoundary>
            <AppShell>
                <Screen />
            </AppShell>
        </ErrorBoundary>
    );
}
