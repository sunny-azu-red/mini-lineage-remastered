# ⚔️ Mini-Lineage Remastered

**Mini-Lineage Remastered** is a modern, high-performance, full-stack rewrite of the classic text-based RPG. Built with TypeScript, Node.js, Express, and WebSocket technology, it revitalizes the nostalgic gameplay loop with real-time state synchronization, procedural 8-bit audio synthesis, and an aesthetic dark fantasy user interface.

## 🌟 Key Features

### 🎮 Gameplay & Combat
- **Distinct Racial Profiles**: Choose between **Humans**, **Orcs**, **Elves**, and **Dark Elves**, each featuring unique starting stats, innate critical chances, ambush risks, and passive HP regeneration rates.
- **Tactical Combat Simulation**: Dynamically scaled encounters where Weapon Attack scales enemy party sizes and Armor Defense sub-linearly mitigates incoming damage.
- **Punchy Critical Strikes**: Tuned `1.9x` critical reward multiplier that doubles enemy kill counts and delivers substantial XP & Adena payout spikes.
- **Chain Ambush Engine**: Dynamic danger calculations with consecutive ambush tracking that inflicts the `Hexed` debuff (`+4% Ambush Risk`, `-2% Crit`) on reckless adventurers.
- **Equipment & Progression**: 6 weapon tiers and 6 armor tiers with innate stat modifiers (e.g. *Eternal Aegis*, *Calamity Comet*), scaling up to level 50.

### 🎧 Procedural 8-Bit Web Audio Engine
- **Zero Audio Assets**: 100% synthesized in real time via the browser's native `AudioContext`, `OscillatorNode`, and `GainNode`.
- **Event-Driven Soundscapes**: Custom waveforms and arpeggios for Game Start, Critical Hits, Ambush Alarms, Level Up Fanfares, Inn Dining, Shop Purchases, and Death.
- **Universal Data Triggers**: Clean, declarative `data-sound` integration decoupled from DOM text or route changes.
- **Client Mute Controls**: Persistent audio toggle stored in `localStorage` with non-blocking UI controls.

### ⚡ Real-Time Engine & Zones
- **Server-Side Tick Cadence**: Periodic 5-second tick loop handling passive HP regeneration and buff/debuff expiration.
- **Zone Classifications**:
  - *Resting Zones* (`/`, `/inn`, `/shop/*`, `/character`, `/highscores`): Peaceful areas that restore health over time.
  - *Combat Zones* (`/battle`, `/death`, `/suicide`): Hostile territory that pauses passive health recovery.
- **WebSocket Streaming**: Live bi-directional HP and status synchronization via Socket.IO, complemented by smooth client-side visual progress ticks.

### 🍖 Inn & Consumables
- **Tiered Food Buffs**: Satisfying meals ranging from *Smoked Sausage* to *Gourmet Feast* that heal current HP and temporarily expand maximum health pool.

### 🏆 Leaderboards & Statistics
- **Live Leaderboards**: Tracks top adventurers sorted by Level, Adena, and Experience.
- **Global Game Statistics**: Aggregates community milestones (Total Battles, Adena Circulated, Enemies Slain, Critical Strikes, Deaths, and Ambushes) with atomic MySQL transactions.

### 🛡️ Security & Reliability
- **Concurrency Locks**: Session-scoped lock middleware preventing duplicate submission and race conditions.
- **Security Hardening**: Hardened with Helmet headers, Gzip compression, sanitized sessions, and sliding-window rate limiting.

## 🛠️ Tech Stack

- **Backend Runtime**: Node.js & Express.js 5
- **Language**: TypeScript (Strict type safety across models, services, and views)
- **Real-Time Communication**: Socket.IO
- **Database & Storage**: MySQL 8+ with Connection Pooling & `express-mysql-session`
- **Audio Engine**: Web Audio API (Procedural Synthesizer)
- **Templating**: EJS (Embedded JavaScript)
- **Logging**: Pino & Pino-Pretty
- **Testing**: Vitest with v8 Coverage (420+ automated unit & integration tests)
- **Asset Pipeline**: Clean-CSS, Terser, HTML-Minifier-Terser

## 📦 Installation & Setup

### 1. Clone & Install Dependencies
```bash
git clone https://github.com/your-username/mini-lineage-remastered.git
cd mini-lineage-remastered
npm install
```

### 2. Environment Configuration
Create a `.env` file in the root directory based on `.env.example`

### 3. Database Migration
Run database migrations to initialize tables and seed baseline data:
```bash
npm run db:migrate
```

## 🚀 Running the Application

### Development Mode
Runs with hot-reloading via `nodemon` and `ts-node`:
```bash
npm run dev
```
Visit `http://localhost:3000` in your browser.

### Production Build & Run
Executes unit tests, compiles TypeScript, aliases path imports, bundles and minifies CSS/JS/HTML assets, and starts the optimized production server:
```bash
npm run prod
```

Or step-by-step:
```bash
npm run build
npm start
```

## 🧪 Testing & Verification

Run the full test suite (35 test files covering all controllers, middlewares, services, and math algorithms):
```bash
# Run all tests once
npm test

# Run tests with code coverage report
npx vitest run --coverage

# Watch mode for active development
npm run test:watch
```

### 🔬 Balance Simulation Tools
Interactive standalone simulation scripts are available under `scratch/`:
```bash
# Analyze Critical Hit reward balance across 10,000 battles per tier:
npm run ts -- scratch/check_crit_balance.ts

# Analyze Leveling Speed & Game Economy:
npm run ts -- scratch/check_economy_balance.ts
npm run ts -- scratch/simulate_full_progression.ts
```

## 🗄️ Database Commands

- `npm run db:migrate`: Applies any pending migrations safely to your schema.
- `npm run db:fresh`: Drops all tables and re-runs migrations from scratch (**Destructive: Use with caution!**).

## 📜 License

MIT License © 2026 Sunny
