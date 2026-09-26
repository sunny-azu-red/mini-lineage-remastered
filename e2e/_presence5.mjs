import { chromium } from 'playwright';
const b = await chromium.launch();
const BASE = 'http://localhost:4002';
const ready = (p) => p.waitForFunction(() => window.liveSocket?.isConnected(), null, { timeout: 15000 });
const create = async (ctx, name) => {
  const p = await ctx.newPage(); await p.goto(BASE + '/'); await ready(p);
  await p.fill('#main input[name="name"]', name); await p.selectOption('#main select[name="race_id"]', '0');
  await p.click('#main form button[type="submit"]'); await p.waitForSelector('#screen[data-screen="home"]');
  return p;
};
for (const [label, longpoll, started] of [['websocket, spectator with a run', false, true], ['long-poll player, spectator with a run', true, true]]) {
  const name = 'Z' + Math.random().toString(36).slice(2, 7);
  const sctx = await b.newContext();
  const spectator = started ? await create(sctx, 'Watcher' + name.slice(1)) : await sctx.newPage();
  const pctx = await b.newContext();
  if (longpoll) await pctx.route('**/live/websocket**', route => route.abort());
  const player = await create(pctx, name);
  const transport = await player.evaluate(() => window.liveSocket.socket.transport?.name || (window.liveSocket.socket.transport === window.Phoenix?.LongPoll ? 'longpoll' : String(window.liveSocket.socket.transport).slice(0, 30)));
  await spectator.goto(BASE + '/highscores'); await ready(spectator);
  const dot = () => spectator.evaluate((n) => { const r = [...document.querySelectorAll('#halls-rows tr')].find(r => r.querySelector('td a')?.textContent.trim() === n); return r ? (/lit/.test(r.querySelector('.online').className) ? 'ON' : 'off') : 'no row'; }, name);
  for (let i = 0; i < 40 && (await dot()) !== 'ON'; i++) await spectator.waitForTimeout(250);
  const before = await dot();
  const t0 = Date.now();
  await player.close();
  let after = await dot();
  while (after === 'ON' && Date.now() - t0 < 40000) { await spectator.waitForTimeout(500); after = await dot(); }
  console.log(`${label.padEnd(40)} transport=${transport} before=${before} after=${after} in ${Date.now() - t0}ms`);
  await pctx.close(); await sctx.close();
}
await b.close();
