import { chromium } from 'playwright';
const b = await chromium.launch();
const BASE = 'http://localhost:4002';
const ready = (p) => p.waitForFunction(() => window.liveSocket?.isConnected());
const create = async (ctx, name) => {
  const p = await ctx.newPage(); await p.goto(BASE + '/'); await ready(p);
  await p.fill('#main input[name="name"]', name); await p.selectOption('#main select[name="race_id"]', '0');
  await p.click('#main form button[type="submit"]'); await p.waitForSelector('#screen[data-screen="home"]');
  return p;
};
async function scenario(label, setup) {
  const name = 'P' + Math.random().toString(36).slice(2, 7);
  const spectatorCtx = await b.newContext();
  const spectator = label.includes('started spectator') ? await create(spectatorCtx, 'S' + name) : await spectatorCtx.newPage();
  const playerCtx = await b.newContext();
  const player = await create(playerCtx, name);
  await setup(player);
  await spectator.goto(BASE + '/highscores'); await ready(spectator);
  const dot = () => spectator.evaluate((n) => [...document.querySelectorAll('#halls-rows tr')].find(r => r.textContent.includes(n))?.querySelector('.online')?.className ?? 'no row', name);
  for (let i = 0; i < 20 && !/lit/.test(await dot()); i++) await spectator.waitForTimeout(250);
  const before = await dot();
  await player.close();
  let after = await dot();
  for (let i = 0; i < 24 && /lit/.test(after); i++) { await spectator.waitForTimeout(500); after = await dot(); }
  console.log(`${label.padEnd(44)} before="${before}" after="${after}"`);
  await playerCtx.close(); await spectatorCtx.close();
}
await scenario('tab closed on Town', async () => {});
await scenario('tab closed after a fight', async (p) => { await p.goto(BASE + '/battle'); await ready(p); await p.click('#main button[phx-click="fight"]'); await p.waitForTimeout(500); });
await scenario('tab closed while on the Halls', async (p) => { await p.goto(BASE + '/highscores'); await ready(p); });
await scenario('tab closed on its own record', async (p) => { await p.click('#sidebar .stat-row a'); await p.waitForTimeout(500); });
await scenario('started spectator, tab closed on Town', async () => {});
await b.close();
