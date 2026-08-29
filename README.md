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
- **Gesture-Safe Unlock**: A single capture-phase pointer/keyboard listener resumes the `AudioContext` on the very first user interaction — sounds are triggered directly from socket-ack handlers, not DOM markers, so nothing ever races a reload.
- **Client Mute Controls**: Persistent audio toggle stored in `localStorage` with non-blocking UI controls.

### ⚡ Real-Time Engine & Zones
- **Server-Side Tick Cadence**: Periodic 5-second tick loop handling passive HP regeneration and buff/debuff expiration.
- **State-Derived Zones**: Combat vs. resting is derived purely from player state (`ambushed`, or a fight within the last 10s) — not the URL being viewed — so simply looking at a screen can never mutate or exploit zone status.
- **WebSocket Streaming**: The React SPA and the server communicate exclusively over one Socket.IO connection (`/socket.io`) — live bi-directional HP/status sync, push updates on tick/effect-expiry, and every player action, with no page reloads.

### 🍖 Inn & Consumables
- **Tiered Food Buffs**: Satisfying meals ranging from *Smoked Sausage* to *Gourmet Feast* that heal current HP and temporarily expand maximum health pool.

### 🏆 Leaderboards & Statistics
- **Live Leaderboards**: Tracks top adventurers sorted by Level, Adena, and Experience.
- **Global Game Statistics**: Aggregates community milestones (Total Battles, Adena Circulated, Enemies Slain, Critical Strikes, Deaths, and Ambushes) with atomic MySQL transactions.

### 🛡️ Security & Reliability
- **Concurrency Locks**: Per-session mutex around every socket mutation (`withSession`), preventing duplicate submissions and race conditions.
- **Security Hardening**: Hardened with Helmet headers (CSP, no inline scripts), Gzip compression, sanitized sessions, and sliding-window rate limiting per socket event.

## 🛠️ Tech Stack

- **Backend Runtime**: Node.js & Express.js 5 (serves the built SPA + one `/api/bootstrap` route; all game actions run over Socket.IO)
- **Frontend**: React 19 + Vite, Zustand for state, no router dependency (`useHistorySync` handles Back/Forward for the handful of link-worthy URLs)
- **Language**: TypeScript (Strict type safety end-to-end, including a shared `shared/` contract imported by both server and client)
- **Real-Time Communication**: Socket.IO (sole transport for client↔server actions/queries and server→client push)
- **Database & Storage**: MySQL 8+ with Connection Pooling & `express-mysql-session`
- **Audio Engine**: Web Audio API (Procedural Synthesizer)
- **Logging**: Pino & Pino-Pretty
- **Testing**: Vitest with v8 Coverage, two projects (server + jsdom-based client component tests)

## 📦 Installation & Setup

### 1. Clone & Install Dependencies
```bash
git clone https://github.com/your-username/mini-lineage-remastered.git
cd mini-lineage-remastered
npm install
```

### 2. Environment Configuration
Copy the example environment file and update credentials as needed. The `DEV_`-prefixed vars
(frontend dev server port, backend URL for the Vite proxy) are dev-only and ignored in production:
```bash
cp .env.example .env
```

### 3. Database Migration
Run database migrations to initialize tables and seed baseline data:
```bash
npm run db:migrate
```

## 🚀 Running the Application

### Development Mode
Runs two processes side by side — the Express/Socket.IO API (via `nodemon`/`ts-node`) and the Vite dev server for the React client (which proxies `/socket.io` and `/api` to the API):
```bash
npm run dev
```
Visit `http://localhost:5173` in your browser by default (configurable via `DEV_FRONTEND_PORT` in `.env`; the API alone listens on `http://localhost:3000`, but has no client assets to serve in dev).

### Production Build & Run
Runs the test suite, builds the client (Vite, into `dist/public`) then the server (`tsc`/`tsc-alias`, into `dist/backend`), and starts the optimized production server — which now serves the built client directly:
```bash
npm run prod
```

Or step-by-step:
```bash
npm run build
npm run start
```
Visit `http://localhost:3000` in your browser.

## 🧪 Testing & Verification

Run the full test suite (server + React client component tests, as two Vitest projects):
```bash
# Run all tests once
npm run test

# Run tests with code coverage report
npm run test:coverage

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
