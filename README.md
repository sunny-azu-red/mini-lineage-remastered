# ⚔️ Mini-Lineage Remastered

**Mini-Lineage Remastered** is a modern, full-stack rewrite of the classic text-based RPG. Built with TypeScript, Node.js, Express, and Socket.IO, it revitalizes the nostalgic gameplay loop with real-time state synchronization, procedural 8-bit audio synthesis, and an aesthetic dark fantasy user interface.

## 🌟 Key Features

### 🎮 Gameplay & Combat
- **Distinct Racial Profiles**: Choose between **Humans**, **Orcs**, **Elves**, and **Dark Elves**, each with its own starting health, inheritance, innate critical chance, ambush risk, and passive HP regeneration — plus a fixed rival race you fight for the whole run.
- **Tactical Combat Simulation**: Dynamically scaled encounters where Weapon Attack drives enemy party size, XP and Adena payouts, while Armor Defense mitigates incoming damage *sub-linearly* so stacking armor never reaches invincibility.
- **Punchy Critical Strikes**: A `1.9×` critical multiplier applied to enemies slain, XP, and Adena alike, so a crit stays impactful at every attack tier.
- **Chain Ambush Engine**: Every fight rolls a fresh ambush against your live ambush risk. Two consecutive ambushes inflict the `Hexed` debuff (`+4% Ambush Risk`, `-2% Crit`, 1 minute), snowballing the danger for reckless adventurers.
- **Equipment & Progression**: 6 weapon tiers and 6 armor tiers, the top ones carrying innate modifiers (*Calamity Comet*'s crit, *Eternal Aegis*' regen), across a level curve that runs to **level 80**.

### 🎧 Procedural 8-Bit Web Audio Engine
- **Zero Audio Assets**: 100% synthesized in real time via the browser's native `AudioContext`, `OscillatorNode`, and `GainNode`.
- **Event-Driven Soundscapes**: Seven declaratively-defined voices — Game Start, Critical Hit, Ambush Alarm, Level Up Fanfare, Inn Dining, Shop Purchase, and Death.
- **Gesture-Safe Unlock**: A single capture-phase pointer/keyboard listener resumes the `AudioContext` on the very first user interaction — sounds fire from socket-ack handlers, not DOM markers, so nothing ever races a reload.
- **Client Mute Controls**: Persistent audio toggle stored in `localStorage` with non-blocking UI controls.

### ⚡ Real-Time Engine & Zones
- **Server-Side Tick Cadence**: A 5-second tick loop applies passive HP regeneration and sweeps expired buffs/debuffs, alongside exact per-effect timers so an expiry fires to the millisecond rather than waiting for the next tick.
- **Location-Based Zones**: The client reports its current screen (`player:screen`); the server classifies that as a combat zone (Battleground, Suicide, Death — regeneration pauses) or a resting zone (Town, Inn, Shops, Character, Highscores — regeneration applies). Being *ambushed* forces combat regardless of what the client claims, so a raw socket client can never lie its way out of one.
- **Disengaging Takes Five Seconds**: Leaving a combat zone does not rest you instantly — ⚔️ *In Combat* stays, gains a 5-second countdown, and only when that elapses does 💤 *Resting* take over and regeneration resume. Standing in a combat zone keeps you flagged *indefinitely* with no countdown at all, so waiting on the Battleground never restores a single point of health. The countdown is anchored to leaving the zone, so stepping back in cancels it and stepping out again starts a fresh one.
- **Regeneration Is Earned, Not Assumed**: 🌿 *Regenerating* is derived per snapshot rather than stored, so it appears and vanishes on its own: it needs the resting aura, a wound, and a positive HP-regen rate at once. An Orc (no innate regen) never sees it; a player at full health loses it the instant they top up.
- **Non-Mutating Reads**: Connecting, reconnecting, or refreshing only ever *reads* state. A fight happens exclusively on an explicit `battle:fight` — never on page load — which makes the classic navigate-away-mid-ambush exploit structurally impossible instead of merely punished.
- **WebSocket Streaming**: The React SPA and the server communicate exclusively over one Socket.IO connection (`/socket.io`) — bi-directional HP/status sync, push updates on tick and effect expiry, and every player action, with no page reloads. Multiple tabs on one session stay in sync.
- **Honest Loading States**: Waiting for data, receiving nothing, and failing to reach the server are three distinct states, never collapsed into one. A screen still fetching shows a spinner rather than announcing an empty leaderboard; a failed request raises the shared notice banner instead of passing an outage off as "nothing here yet". The footer names the running build even before the server answers, so an unreachable backend still tells you which bundle is loaded.

### 🍖 Inn & Consumables
- **Tiered Meals**: Five dishes from *Spiced Ale* to *Roasted Pheasant*. All restore HP; the top three also grant a timed buff (*Satisfied*, *Well Fed*, *Gourmet Feast*) that temporarily expands the maximum health pool. Only one food buff is active at a time — a new meal replaces the old one.

### 🏆 Leaderboards & Statistics
- **Live Leaderboards**: The top 25 adventurers ordered by total Experience, then Adena — filterable per race. Cowards and cheaters are barred from posting.
- **Global Game Statistics**: 20 community counters (battles fought, Adena circulated and spent, enemies slain, critical strikes, damage blocked, HP lost/healed/regenerated, deaths, ambushes, and more), each maintained with an atomic MySQL upsert.

### 🛡️ Security & Reliability
- **One Place For Every Access Rule**: `pinScreen` decides where a player is allowed to be, and every navigation funnels through it — an in-app link, a typed URL and the Back button all obey the same checks. The dead are confined to the death screen; the living are kept *off* it (it offers "Play Again?", which wipes the character); a player with a character cannot wander back into character creation, Statistics or Races; a visitor without one is confined to Game Start, Statistics, Races and Highscores; and an ambushed player is pinned to the battleground.
- **Guarded Mutations**: Every socket event that changes state declares its own preconditions (`requireStarted`, `requireNotStarted`, `requireAlive`, `requireDead`, `requireHighscoreEligible`), enforced server-side inside the session lock. Client-side routing is convenience; these guards are the boundary. Notably `game:restart` requires a *dead* character, so a living one can never be wiped — not even by a hand-rolled socket client.
- **Concurrency Locks**: A per-session promise mutex wraps every socket mutation (`withSession`), so concurrent actions on one session can never interleave into a lost update.
- **Revision-Guarded State**: Every persisted mutation bumps a monotonic `revision`, letting the client drop out-of-order pushes instead of letting a stale one clobber fresher state.
- **Security Hardening**: Helmet headers (CSP with no inline scripts), Gzip compression, `httpOnly`/`sameSite` session cookies, Zod validation on every socket payload, and sliding-window rate limiting (60 battles and 30 shop actions per minute, plus a 300/min flood limiter on every event). Rate limits are bypassed outside a release build so local development isn't throttled.

## 🛠️ Tech Stack

- **Backend Runtime**: Node.js & Express.js 5 (serves the built SPA + one `/api/bootstrap` route; all game actions run over Socket.IO)
- **Frontend**: React 19 + Vite, Zustand for state, no router dependency (`useHistorySync` maps the handful of link-worthy URLs to Back/Forward)
- **Language**: TypeScript (strict end-to-end, including a shared `shared/` contract imported by both server and client)
- **Real-Time Communication**: Socket.IO (sole transport for client↔server actions/queries and server→client push)
- **Database & Storage**: MySQL 8+ with connection pooling & `express-mysql-session`
- **Audio Engine**: Web Audio API (procedural synthesizer)
- **Logging**: Pino & Pino-Pretty
- **Testing**: Vitest with v8 coverage, split into two projects (Node-based server tests + jsdom-based client component tests)

Requires **Node.js 22.12+**.

## 📦 Installation & Setup

### 1. Clone & Install Dependencies
```bash
git clone https://github.com/sunny-azu-red/mini-lineage-remastered.git
cd mini-lineage-remastered
npm install
```

### 2. Environment Configuration
Copy the example environment file and update credentials as needed. The `DEV_`-prefixed vars
(frontend dev server port, backend host for the Vite proxy) are dev-only and ignored in production:
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
Visit `http://localhost:5173` in your browser by default (configurable via `DEV_FRONTEND_PORT` in `.env`). The API alone listens on `http://localhost:3000`, but serves no client assets in dev — hitting it directly just points you back at Vite.

### Production Build & Run
Runs the test suite, builds the client (Vite, into `dist/public`) then the server (`tsc`/`tsc-alias`, into `dist/backend`), and starts the optimized production server — which serves the built client directly:
```bash
npm run prod
```

Or step-by-step:
```bash
npm run build
npm run start
```
Visit `http://localhost:3000` in your browser.

### 🐳 Docker
The included multi-stage `Dockerfile` builds the client and server, then ships only production dependencies. `docker-compose.yml` reads the same `.env` and expects an **external** MySQL instance (it provisions no database of its own), so point `DB_HOST` at one that the container can reach:
```bash
docker compose up --build
```
The container runs pending migrations before starting the server, and sets `IN_DOCKER=true` so session cookies are issued with the `secure` flag.

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

No database is required — the suite stubs the store and repository layers. Coverage sits at
**100% of statements, branches, functions and lines**, and is expected to stay there.

Beyond the unit tests, five suites pin invariants that are easy to break silently:

- **`test/backend/service/balance.golden.test.ts`** — a golden master that plays 400 fights per character across all four races and five fixed RNG seeds, then pins the exact resulting progression. Because every roll runs off one deterministic stream, this also pins the *order* in which `Math.random()` is consumed: adding, removing, or reordering a draw anywhere in the fight path fails here even when each individual function is still correct. **A diff in this file is a deliberate balance change — regenerate it in the same commit.**
- **`test/backend/socket/playthrough.integration.test.ts`** — plays a whole game end-to-end through the real socket stack (start → shop → fight → level → death → highscore → restart) with only the session store and repositories stubbed.
- **`test/frontend/screen-access.test.ts`** — states the access policy above once, end to end, checking every rule through an in-app link, a typed URL *and* the Back button. The three routes must agree; historically they did not.
- **`test/frontend/no-dead-ends.test.tsx`** — liveness. For every player state, whatever screen they are pinned to must render and offer at least one enabled control. Guards against a redirect and a screen's own self-blanking conspiring to strand someone on a page with no way off.
- **`test/frontend/audio/soundfx.trace.test.ts`** — records the exact sequence of Web Audio calls each sound effect emits, so the game provably keeps sounding the same. Retuning a voice means updating its trace.

### 🔬 Balance Simulation Tools
Interactive standalone simulation scripts live under `scratch/`:
```bash
# Compare Critical Hit reward multipliers across 10,000 simulated battles:
npm run ts -- scratch/check_crit_balance.ts

# Analyze leveling speed and the game economy:
npm run ts -- scratch/check_economy_balance.ts
npm run ts -- scratch/simulate_full_progression.ts
```

## 🗄️ Database Commands

- `npm run db:migrate`: Applies any pending migrations safely to your schema.
- `npm run db:fresh`: Drops all tables and re-runs migrations from scratch (**Destructive: use with caution!**).

## 📜 License

MIT — see [LICENSE](LICENSE). © 2026 Sunny
