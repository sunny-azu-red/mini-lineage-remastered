import { useEffect, type ComponentType } from 'react';
import AppShell from './components/layout/AppShell';
import ErrorBoundary from './components/ErrorBoundary';
import { useGameStore, type ScreenId } from './store/gameStore';
import { useHistorySync } from './hooks/useHistorySync';
import { useKonamiRelay } from './hooks/useKonamiRelay';
import { usePanelFocus } from './hooks/usePanelFocus';
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

// Every screen, with the panel heading + <title> for that route. 'error' is the store's explicit
// error state — distinct from ErrorBoundary, which catches an unexpected render throw.
const SCREENS: Record<ScreenId, { component: ComponentType; title: string }> = {
    start: { component: GameStartScreen, title: 'Game Start' },
    home: { component: HomeScreen, title: 'Home Town' },
    inn: { component: InnScreen, title: 'Inn' },
    weapons: { component: WeaponsShopScreen, title: 'Weapons Shop' },
    armors: { component: ArmorsShopScreen, title: 'Armor Shop' },
    suicide: { component: SuicideScreen, title: 'Commit Suicide' },
    battle: { component: BattleScreen, title: 'Battleground' },
    death: { component: DeathScreen, title: 'Game Over' },
    character: { component: CharacterScreen, title: 'Character' },
    highscores: { component: HighscoresScreen, title: 'Hall of Champions' },
    statistics: { component: StatisticsScreen, title: 'The Tome of Lore' },
    races: { component: RacesScreen, title: 'Chronicles of Ancestry' },
    error: { component: ErrorScreen, title: 'Error' },
};

export default function App() {
    const screen = useGameStore(state => state.screen);
    const { component: Screen, title } = SCREENS[screen];

    useHistorySync();
    useKonamiRelay();
    usePanelFocus(screen);

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
