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
for (const started of [false, true]) {
  const name = 'X' + Math.random().toString(36).slice(2, 7);
  const sctx = await b.newContext();
  const spectator = started ? await create(sctx, 'S' + name) : await sctx.newPage();
  const player = await create(await b.newContext(), name);
  await spectator.goto(BASE + '/highscores'); await ready(spectator);
  const xp = () => spectator.evaluate((n) => [...document.querySelectorAll('#halls-rows tr')].find(r => r.textContent.includes(n))?.querySelector('[data-key^="xp-"]')?.dataset.value ?? 'no row', name);
  for (let i = 0; i < 20 && (await xp()) === 'no row'; i++) await spectator.waitForTimeout(250);
  const before = await xp();
  await player.goto(BASE + '/battle'); await ready(player);
  await player.click('#main button[phx-click="fight"]');
  await spectator.waitForTimeout(2500);
  console.log(`spectator ${started ? 'WITH' : 'without'} a character: xp ${before} -> ${await xp()}`);
}
await b.close();
