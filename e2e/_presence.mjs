import { chromium } from 'playwright';
const b = await chromium.launch();
const watcher = await (await b.newContext()).newPage();
const playerCtx = await b.newContext();
const player = await playerCtx.newPage();
await player.goto('http://localhost:4002/'); await player.waitForFunction(() => window.liveSocket?.isConnected());
await player.fill('#main input[name="name"]', 'Present2'); await player.selectOption('#main select[name="race_id"]', '0');
await player.click('#main form button[type="submit"]'); await player.waitForSelector('#screen[data-screen="home"]');
await watcher.goto('http://localhost:4002/highscores'); await watcher.waitForFunction(() => window.liveSocket?.isConnected());
const lit = () => watcher.evaluate(() => {
  const row = [...document.querySelectorAll('#halls-rows tr')].find(r => r.textContent.includes('Present2'));
  return row ? row.querySelector('.online')?.className : 'no row';
});
for (let i = 0; i < 20 && !/lit/.test(await lit()); i++) await watcher.waitForTimeout(250);
console.log('while playing:', await lit());
const t0 = Date.now();
await playerCtx.close();
for (let i = 0; i < 30; i++) {
  await watcher.waitForTimeout(500);
  const c = await lit();
  if (!/lit/.test(c)) { console.log(`went dark after ${Date.now() - t0}ms:`, c); break; }
  if (i === 29) console.log('still lit after 15s:', c);
}
await b.close();
